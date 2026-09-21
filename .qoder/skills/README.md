# .qoder/skills — 技能目录说明

本目录同时容纳**两类**技能，来源与维护方式不同：

1. **Vendored Superpowers 技能**（本 README 与同目录 `LICENSE` 对应这部分）——固定副本，手工同步。
2. **OpenSpec 技能**（`openspec-*` 前缀）——由 `openspec init/update` 生成与维护，**不属于本副本范围**。

---

## 一、Vendored Superpowers（固定副本）

[Superpowers](https://github.com/obra/superpowers) 技能的**固定副本**（vendored），
用于保证所有贡献者环境一致、可复现、离线可用。

- **来源**：全局插件 `superpowers@5.1.0`（`~/.qoder/plugins/cache/qoder-marketplace/superpowers/5.1.0/skills/`）
- **许可证**：MIT（见同目录 `LICENSE`）
- **升级方式**：手动同步（见 `scripts/init-workspace.ps1` 的 `-SuperpowersVersion` 参数），升级后更新本文件版本号

### 已固定技能（8）

| 技能 | 用途 | 工作流阶段 |
|------|------|-----------|
| brainstorming | 需求/设计澄清 | Explore |
| writing-plans | 编写实施计划 | Plan |
| executing-plans | 执行实施计划 | Implement |
| test-driven-development | RED→GREEN→REFACTOR | Implement |
| systematic-debugging | 系统化排障 | Implement/Verify |
| requesting-code-review | 发起代码评审 | Verify |
| receiving-code-review | 接收/处理评审意见 | Verify |
| verification-before-completion | 完成前验证 | Verify/Complete |

> 技能的“发现与触发”由 `AGENTS.md` 与 `.qoder/rules/workflow-conventions.md` 强制约束，
> 替代全局插件的 SessionStart 钩子作用。

---

## 二、OpenSpec 技能（由 CLI 维护，勿手工改动）

随 `openspec init --tools qoder` 生成，对应 `/opsx:*` 斜杠命令，升级请用 `openspec update`：

| 技能 | 对应命令 |
|------|---------|
| openspec-explore | `/opsx:explore` |
| openspec-propose | `/opsx:propose` |
| openspec-apply-change | `/opsx:apply` |
| openspec-archive-change | `/opsx:archive` |
| openspec-sync-specs | `/opsx:sync` |
| openspec-update-change | `/opsx:update` |

> 许可证以 OpenSpec 项目（https://github.com/Fission-AI/OpenSpec）为准，与上面的 Superpowers MIT `LICENSE` 相互独立。
