# CLAUDE.md — Claude 代理配置

> 本文件为 Claude 代理提供项目特定配置入口。**完整规则见 `AGENTS.md`**，本文件仅作导航。

## 项目方法论

本项目使用 **Spec-Driven Development (SDD)**：
- 规格（`openspec/specs/`）是真相源
- 变更通过 OpenSpec 结构化流程管理
- AI 代理行为受 `.harness/` 约束

## 产品

**AnanoesisShell** — AI 驱动的远程终端：用户无需记忆命令，由 AI 自动完成 Linux 运维操作。

## 开发工作流

1. 读取 `AGENTS.md` 了解全部项目约束
2. 读取 `.harness/guides/workflow.md` 了解开发流程
3. 读取 `.qoder/known-issues.md` 了解已知陷阱
4. 读取 `openspec/specs/` 了解当前规格
5. 在相应场景触发 `.qoder/skills/` 中的技能
6. 完成后对照 `.harness/sensors/quality.md` 验证

## 约束

- 遵循 `AGENTS.md` 中的所有规则
- **技术栈当前未锁定**：禁止擅自引入具体业务框架 / 依赖，选型须经 OpenSpec 变更流程
- 不得跳过测试；不得在无 spec 的情况下实现功能；完成前必须运行验证
