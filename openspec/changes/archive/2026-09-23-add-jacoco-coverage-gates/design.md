## Context

当前 `backend/pom.xml` 无 JaCoCo 依赖，Surefire argLine 已含 mockito javaagent 和 ByteBuddy 参数。项目为多仓库架构（主控 + frontend/ + backend/ 子仓库），git hooks 完全缺失（仅 `.git/hooks/*.sample`）。

JaCoCo 基线测量结果（排除 contract/entity/mapper/package-info/Application 后）：
- 分支覆盖率 65.9%（1365/2072）
- 重灾区：ws 43.8%、controller 41.4%、config 54.2%、ssh 57.7%

## Goals / Non-Goals

**Goals:**
- JaCoCo 分支覆盖率度量集成到 Maven 构建生命周期
- 渐进式阈值：初始 65%，后续提升到 70%+
- pre-commit hook：快速门禁（后端编译 + 前端 type-check/test），秒级反馈
- pre-push hook：覆盖率门禁（mvn verify + JaCoCo check）
- 一键安装脚本为三个仓库配置 hook
- 修复 PtyCommandSchedulerTest flaky test

**Non-Goals:**
- 前端覆盖率度量（仅做 type-check + test 快速门禁）
- CI 集成（后续单独变更）
- 100% 覆盖率目标
- 增量覆盖率检查（仅做全量）

## Decisions

### D1: JaCoCo 插件配置方式

**选择**: `jacoco-maven-plugin` 0.8.12，三个 execution（prepare-agent / report / check）

**Surefire argLine 适配**: 在现有参数前追加 `@{argLine}`（Maven 延迟属性解析），让 JaCoCo prepare-agent 设置的 `${argLine}` 属性自动拼接：

```xml
<argLine>
    @{argLine}
    -javaagent:${org.mockito:mockito-core:jar}
    -Dnet.bytebuddy.experimental=true
    -Djdk.net.URLClassPath.disableClassPathURLCheck=true
</argLine>
```

**替代方案**: 手动拼接 JaCoCo agent 路径到 argLine。放弃原因：`@{argLine}` 是 Maven 标准做法，prepare-agent 自动管理 agent 路径和排除参数。

### D2: 覆盖率排除规则

```
排除清单（JaCoCo <excludes>）：
  - com/ananoesis/shell/contract/**       OpenAPI 生成物
  - com/ananoesis/shell/entity/**         纯 getter/setter 样板
  - com/ananoesis/shell/mapper/**         MyBatis-Plus 纯接口
  - **/package-info.class                 无代码
  - com/ananoesis/shell/AnanoesisShellApplication.class  启动入口
```

异常类不整体排除：含静态工厂（如 `HostNotFoundException.forId()`）的由测试覆盖；纯构造器委托的代码量极小，对数字影响可忽略。

### D3: 阈值策略

**选择**: 渐进式，初始 65%（当前基线 65.9%）

```xml
<rule>
    <element>BUNDLE</element>
    <limits>
        <limit>
            <counter>BRANCH</counter>
            <value>COVEREDRATIO</value>
            <minimum>0.65</minimum>
        </limit>
    </limits>
</rule>
```

**替代方案**: 按包设不同阈值。放弃原因：BUNDLE 级别更简单，避免包间互相掩盖退化。后续可按需细化。

### D4: Git hook 方案

**选择**: 方案 B — `.githooks/` 目录 + bash shim + PowerShell 主体

```
.githooks/
  pre-commit          bash shim (3-5 行) → 调用 scripts/hook-pre-commit.ps1
  pre-push            bash shim (3-5 行) → 调用 scripts/hook-pre-push.ps1
scripts/
  hook-pre-commit.ps1  快速门禁逻辑
  hook-pre-push.ps1    覆盖率门禁逻辑
  install-hooks.ps1    一键安装
```

**为什么 bash shim**: Git for Windows 的 hook 由 bash 执行，不能直接运行 .ps1。bash shim 极薄（`powershell -NoProfile -ExecutionPolicy Bypass -File "$(git rev-parse --show-toplevel)/scripts/hook-pre-commit.ps1"`），实际逻辑全在 PowerShell 中，与项目脚本体系一致。

**替代方案 A**: Husky + lint-staged。放弃原因：引入 Node.js 依赖，且子仓库需独立安装。
**替代方案 C**: 纯 bash 脚本。放弃原因：与项目 PowerShell 脚本体系不一致，Windows 路径处理复杂。

### D5: Hook 检查内容

**pre-commit（快速门禁，目标 <15s）**:
- 检测变更文件范围（`git diff --cached --name-only`）
- backend/ 有变更 → `mvn compile -f backend/pom.xml -q`（仅编译，不跑测试）
- frontend/ 有变更 → `npm --prefix frontend run type-check` + `npm --prefix frontend run test`

**pre-push（覆盖率门禁，目标 <3min）**:
- backend/ 有变更 → `mvn verify -f backend/pom.xml`（跑测试 + JaCoCo report + check）
- JaCoCo check 分支覆盖率 >= 阈值 → 通过
- backend/ 无变更 → 跳过

### D6: 多仓库 hook 安装

`scripts/install-hooks.ps1` 为三个仓库分别配置 `core.hooksPath`：

```
主控仓库:  git config core.hooksPath .githooks
frontend/: git config core.hooksPath ../.githooks
backend/:  git config core.hooksPath ../.githooks
```

frontend 和 backend 共享主控的 `.githooks/` 目录（通过相对路径引用），hook 脚本内部已包含前后端检查逻辑。

### D7: Flaky test 修复

`PtyCommandSchedulerTest.activeOutputExtendsTimeout` 的 collectOutput 间隔（100ms）与超时阈值（200ms）比值太紧（2:1），Windows 线程调度抖动可导致误触发。

**修复**: 增大比值为 5:1（间隔 100ms / 阈值 500ms），或改用 `CountDownLatch` 替代 `Thread.sleep` 做确定性等待。

## Risks / Trade-offs

- **[风险] pre-push 耗时 1-3 分钟** → 开发者可能用 `--no-verify` 绕过。缓解：后续接入 CI 作为第二道防线。
- **[风险] IDE 与 Maven 并发编译冲突** → 已知导致 PtyCommandSchedulerTest 假性编译错误。缓解：hook 脚本检测 IDE 锁文件时提示用户。
- **[风险] JaCoCo 报告仅在主代码编译后生成** → 如果编译失败则无报告。缓解：pre-push 在 verify 失败时直接报错，不需要报告。
- **[权衡] BUNDLE 级阈值 vs 包级阈值** → BUNDLE 级更简单但可能掩盖局部退化。后续可细化。
- **[权衡] 全量覆盖率 vs 增量覆盖率** → 全量更严格但更慢。增量实现复杂且 JaCoCo 原生不支持。
