## Why

项目当前没有任何代码覆盖率度量和 git hook 门禁。141 个 Java 源文件、85 个测试文件，分支覆盖率未知。无法在提交或推送时阻止覆盖率退化。需要引入 JaCoCo 分支覆盖率度量 + pre-commit/pre-push git hook，建立质量基线并渐进提升。

## What Changes

- **JaCoCo Maven 插件集成**：在 `backend/pom.xml` 添加 `jacoco-maven-plugin`，配置 `prepare-agent`、`report`、`check` 三个 execution，对排除后的代码执行分支覆盖率检查
- **排除规则**：排除 OpenAPI 生成代码（`contract/**`）、entity 纯样板、mapper 纯接口、`package-info.java`、`AnanoesisShellApplication` 启动入口
- **渐进式阈值**：初始 65%（当前基线 65.9%），后续提升到 70%+
- **Surefire argLine 适配**：在现有 mockito agent 参数前追加 `@{argLine}` 以兼容 JaCoCo agent 注入
- **Git hook 脚本**：方案 B（`.githooks/` 目录 + 手写脚本），包含 pre-commit（快速门禁：编译 + 前端 type-check/test）和 pre-push（覆盖率门禁：`mvn verify` + JaCoCo check）
- **Hook 安装脚本**：`scripts/install-hooks.ps1` 一键为三个仓库（主控 + frontend + backend）配置 `core.hooksPath`
- **前端快速门禁**：pre-commit 中对 frontend 执行 `type-check` + `test`（不做覆盖率）
- **修复 PtyCommandSchedulerTest flaky test**：`activeOutputExtendsTimeout` 时序敏感，需增大超时裕量

## Capabilities

### New Capabilities

无新增用户可观察行为的能力。

### Modified Capabilities

无修改现有规格的行为。

> 本变更为纯开发工具链/工作流变更，不改变系统对外行为。设置 `skip_specs: true`。

## Impact

- **`backend/pom.xml`**：新增 JaCoCo 插件配置、修改 Surefire argLine
- **`.githooks/`**：新增 pre-commit、pre-push 脚本（bash shim + PowerShell 主体）
- **`scripts/install-hooks.ps1`**：新增 hook 安装脚本
- **`backend/src/test/`**：可能需修复 PtyCommandSchedulerTest flaky test
- **开发者工作流**：首次 clone 后需运行 `scripts/install-hooks.ps1` 启用 hook
- **CI/构建**：`mvn verify` 现在会额外执行 JaCoCo 报告生成和覆盖率检查，构建时间增加约 10-20%
