# AnanoesisShell
AnanoesisShell is an AI-powered remote terminal. Users don’t need to think about commands — the AI automatically handles Linux operations.

---

## 项目状态

🚧 **基础结构初始化阶段** —— 当前仓库仅落地工程治理骨架（SDD + Harness + OpenSpec + Superpowers），**业务技术栈尚未锁定**，前后端框架将通过 OpenSpec 变更流程决定。

## 架构（AI Workspace）

主控仓库（本仓库）+ 两个 `git submodule` 子仓库，前后端分离：

| 仓库 | 角色 |
|------|------|
| 主控仓库（本仓库） | 规格 / 约束门禁 / 多代理编排 / 文档 |
| `frontend/` | 前端代码（技术栈待定） |
| `backend/` | 后端代码（技术栈待定） |

## 快速开始

```powershell
# 1. 克隆（含子模块）
git clone --recurse-submodules https://github.com/13198582183/AnanoesisShell.git
cd AnanoesisShell

# 2. 若已克隆但子模块为空，初始化子模块
git submodule update --init --recursive

# 3. 校验工作区结构完整性
.\scripts\verify-structure.ps1

# 4. 查看 OpenSpec 规格与变更
openspec list
```

## 工程规范

本项目遵循 **Spec-Driven Development (SDD)**：

- **规格真相源**：`openspec/specs/`；变更走 `/opsx:propose → /opsx:apply → /opsx:archive`
- **约束门禁**：`.harness/guides/`（前馈）+ `.harness/sensors/`（反馈）
- **AI 代理技能**：`.qoder/skills/`（vendored Superpowers）
- **代理指南**：见 `AGENTS.md`；已知陷阱见 `.qoder/known-issues.md`

## 文档

- 设计规格：`docs/superpowers/specs/`
- 实施计划：`docs/superpowers/plans/`

## 许可证

[MIT](./LICENSE)
