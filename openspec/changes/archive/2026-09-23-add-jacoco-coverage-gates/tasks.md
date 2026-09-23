## 1. JaCoCo Maven 插件集成

- [x] 1.1 在 `backend/pom.xml` 添加 `jacoco-maven-plugin` 0.8.12，配置 prepare-agent / report / check 三个 execution，排除 contract/entity/mapper/package-info/Application，check 阈值设为 BRANCH COVEREDRATIO >= 0.65。验证：`mvn clean verify` 成功且 `target/site/jacoco/jacoco.csv` 生成
- [x] 1.2 修改 Surefire argLine，在现有 mockito agent 参数前追加 `@{argLine}`。验证：`mvn clean test` 通过且 JaCoCo agent 正常注入（jacoco.exec 文件生成）

## 2. Flaky Test 修复

- [x] 2.1 修复 `PtyCommandSchedulerTest.activeOutputExtendsTimeout`：增大 collectOutput 间隔与超时阈值的比值至 5:1（如间隔 100ms / 阈值 500ms）。验证：连续运行 5 次 `mvn test -Dtest=PtyCommandSchedulerTest` 全部通过

## 3. Git Hook 脚本

- [x] 3.1 创建 `.githooks/pre-commit` bash shim（调用 `scripts/hook-pre-commit.ps1`）。验证：文件存在且可执行
- [x] 3.2 创建 `.githooks/pre-push` bash shim（调用 `scripts/hook-pre-push.ps1`）。验证：文件存在且可执行
- [x] 3.3 创建 `scripts/hook-pre-commit.ps1`：检测变更范围，backend 有变更时跑 `mvn compile -q`，frontend 有变更时跑 `type-check` + `test`。验证：手动运行脚本，有 backend 变更时编译通过返回 0，故意引入编译错误时返回非 0
- [x] 3.4 创建 `scripts/hook-pre-push.ps1`：检测 backend 变更时跑 `mvn verify`（含 JaCoCo check）。验证：手动运行脚本，覆盖率 >= 65% 时返回 0

## 4. Hook 安装脚本

- [x] 4.1 创建 `scripts/install-hooks.ps1`：为主控仓库配置 `core.hooksPath .githooks`，为 frontend/ 和 backend/ 配置 `core.hooksPath ../.githooks`。验证：运行脚本后 `git config core.hooksPath` 在三个仓库均返回正确路径

## 5. 全量验证

- [x] 5.1 执行完整质量门禁：`mvn clean verify`（后端含 JaCoCo check）、`npm --prefix frontend run type-check`、`npm --prefix frontend run test`、`scripts/verify-structure.ps1`。验证：全部通过，退出码均为 0
- [x] 5.2 验证 hook 端到端：安装 hook 后执行一次 `git commit`（pre-commit 通过）和一次 `git push --dry-run`（pre-push 通过或按预期跳过）。验证：hook 输出可见且退出码正确
