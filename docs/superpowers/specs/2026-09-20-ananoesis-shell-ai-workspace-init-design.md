# AnanoesisShell — AI Workspace 初始化设计

- **日期**: 2026-09-20
- **状态**: Approved（已通过头脑风暴评审，待写实施计划）
- **作者**: liziwen（人类决策） + AI 代理（设计起草）
- **方法论**: Spec-Driven Development (SDD) + Harness 门禁 + Superpowers 纪律

---

## 1. 背景与目标

在空工作区 `f:\project\dev\workspace\AnanoesisShell` 初始化一个采用 **AI Workspace 架构**
的多仓库项目，并接入三个已存在的远端 GitHub 仓库：

| 角色 | 远端地址 | 现状 |
|------|---------|------|
| 主控仓库 | https://github.com/13198582183/AnanoesisShell.git | 已存在，含初始 README（私有，默认分支 `main`） |
| 前端子仓库 | https://github.com/13198582183/AnanoesisShell-frontend.git | 已存在，仅 `README.md`，分支 `main` |
| 后端子仓库 | https://github.com/13198582183/AnanoesisShell-backend.git | 已存在，仅 `README.md`，分支 `main` |

**目标**：完成"基础结构初始化"，落地 SDD + Harness + Superpowers + OpenSpec 的治理骨架，
前后端分离，**当前阶段不锁定具体技术栈**（栈相关部分延后，通过后续 OpenSpec 变更补齐）。

**非目标（本次不做）**：选定前端/后端框架、业务代码、数据库、部署编排、栈相关编码规范。

---

## 2. 决策记录（Decisions Log）

| 编号 | 主题 | 决定 | 理由 |
|------|------|------|------|
| Q1 | 多仓拓扑 | **Git Submodules** | 版本可锁定、结构清晰，AI Workspace 多仓经典做法 |
| Q2 | 规格分布 | **主仓库集中式 `openspec/`** | 单一控制面，统一治理跨前后端需求 |
| Q3/D1 | OpenSpec 命令形态 | **仅原生命令** `openspec init --tools qoder` | 官方支持、`openspec update` 自动维护，避免手工漂移；生成 `.qoder/commands/opsx/*.md` |
| Q4 | Superpowers 集成 | **仓库内 vendored（固定副本）** | 保证所有贡献者环境一致、可复现、离线可用 |
| D2 | 初始化范围 | **完整骨架**（栈无关部分） | 一步到位建立治理层，栈相关延后 |

> 说明：用户既有 7 个项目使用手工 `.qoder/plugins/custom/openspec-plugin/`（skills 形态）；
> 本项目改用 OpenSpec 原生命令，因原生方案由 CLI 维护、随版本升级不漂移。

---

## 3. 架构总览

```
AnanoesisShell (主控仓库 / 控制面)
│   SDD 方法论 · 规格 · 约束门禁 · 多代理编排 · 文档
├── frontend/   [git submodule] → AnanoesisShell-frontend.git  (代码面，空占位)
└── backend/    [git submodule] → AnanoesisShell-backend.git   (代码面，空占位)
```

三大理念落位：

- **OpenSpec** — `openspec/` 为规格真相源；`specs/` 定义系统行为，`changes/` 走
  提案(propose) → 实施(apply) → 归档(archive) 生命周期。
- **Harness** — `.harness/guides/`（前馈控制：行动前注入工作流与规范）+
  `.harness/sensors/`（反馈控制：行动后校验质量与规格漂移）。
- **Superpowers** — `.qoder/skills/` vendored 技能，强制
  explore → design → plan → TDD → review → verify 纪律。

---

## 4. 目标目录结构

```
AnanoesisShell/
├── .gitmodules                 # submodule: frontend, backend（分支 main）
├── .gitignore                  # 忽略 node_modules/.next/target/IDE 等
├── .gitattributes              # 行尾/文本规范化
├── README.md                   # 项目说明（保留/合并远端已有 README）
├── AGENTS.md                   # 代理主指南（引用 harness/openspec/superpowers）
├── CLAUDE.md                   # 兼容入口，指向 AGENTS.md
├── openspec/                   # ★ 集中式规格（openspec init --tools qoder 生成）
│   ├── specs/                  #   规格真相源
│   ├── changes/                #   变更提案
│   │   └── archive/            #   已归档变更
│   ├── schemas/                #   Schema 定义
│   └── README.md
├── .qoder/
│   ├── commands/opsx/          # ★ OpenSpec 原生斜杠命令（/opsx:propose 等）
│   ├── skills/                 # ★ Vendored Superpowers 技能（7 个 + README）
│   │   ├── brainstorming/
│   │   ├── writing-plans/
│   │   ├── executing-plans/
│   │   ├── test-driven-development/
│   │   ├── systematic-debugging/
│   │   ├── code-review/
│   │   └── verification-before-completion/
│   ├── agents/                 # 多代理团队（栈无关角色定义）
│   ├── rules/                  # 约定规则（本次：workflow-conventions, coding-standards）
│   ├── known-issues.md         # 已知问题日志（开发前必读）
│   └── settings.json           # 项目级 Qoder 设置
├── .harness/
│   ├── README.md               # 约束系统说明
│   ├── guides/
│   │   ├── workflow.md         # 开发工作流指南（前馈）
│   │   └── coding-standards.md # 编码/注释规范（前馈）
│   └── sensors/
│       ├── quality.md          # 质量门禁检查点（反馈）
│       └── drift-detection.md  # 规格漂移检测（反馈）
├── docs/
│   └── superpowers/specs/      # 设计与规格文档（含本文件）
└── scripts/
    ├── init-workspace.ps1      # 一键初始化（幂等）
    └── verify-structure.ps1    # 结构自检 / 门禁校验
```

---

## 5. 组件规格

### 5.1 Git Submodules
- `frontend/` → `https://github.com/13198582183/AnanoesisShell-frontend.git`，分支 `main`
- `backend/`  → `https://github.com/13198582183/AnanoesisShell-backend.git`，分支 `main`
- 保留远端已有 README/历史；子仓库独立提交，主仓库记录指针变更。
- 并行开发约束（写入 `AGENTS.md` 与 `.qoder/rules/workflow-conventions.md`）：
  主仓库建 worktree 时，子仓库必须同步建同名 feature 分支；合并/推送/清理必须
  对主仓库与所有子仓库执行完整闭环（Check → Merge → Clean）。

### 5.2 OpenSpec（原生命令）
- 执行 `openspec init --tools qoder` 生成 `openspec/` 与 `.qoder/commands/opsx/*.md`。
- 生命周期命令：`/opsx:explore`、`/opsx:propose`、`/opsx:apply`、`/opsx:archive`。
- 规格语言：结构关键字（Requirement/Scenario/SHALL）保持 OpenSpec 约定；描述可用中文。
- 校验：`openspec validate --all` 作为提交前门禁。

### 5.3 Vendored Superpowers（`.qoder/skills/`）
- 来源：全局插件 `superpowers@5.1.0`（`~/.qoder/plugins/cache/qoder-marketplace/superpowers/5.1.0/skills/`）。
- 固定这 7 个技能：`brainstorming`、`writing-plans`、`executing-plans`、
  `test-driven-development`、`systematic-debugging`、`code-review`、
  `verification-before-completion`。
- 许可证：MIT，随副本保留 `LICENSE` 与出处标注（`skills/README.md` 注明来源与版本）。
- 与全局插件并存不冲突：项目副本提供可复现的固定版本。

### 5.4 Harness 门禁（`.harness/`）
- **Guides（前馈）**：`workflow.md` 定义 brainstorm → plan → implement → review → verify；
  `coding-standards.md` 定义注释与编码规范（关键业务逻辑必须注释意图）。
- **Sensors（反馈）**：`quality.md` 定义质量/合规检查点；`drift-detection.md` 定义
  实现与 `openspec/specs/` 的漂移检测。
- 在 `AGENTS.md`/`CLAUDE.md` 中引用：遵循 `.harness/guides/`，对照 `.harness/sensors/` 校验。
- 本次为**栈无关骨架**；锁定技术栈后通过 OpenSpec 变更补充具体检查命令。

### 5.5 多代理（`.qoder/agents/`）
- 栈无关角色骨架（**本次落地 7 个**）：ProductManager、Architect、FrontendEngineer、
  BackendEngineer、QAEngineer、CodeReviewer、TaskDispatcher。
- **延后**：UIInteractionEngineer、UXQualityAssurance（依赖 UI/栈定义，锁定技术栈后再补）。
- 每个 agent 定义职责、触发场景、输出契约；不含具体框架细节，待栈锁定后细化。

### 5.6 规则（`.qoder/rules/`）
- 本次落地：`workflow-conventions.md`（含 worktree+submodule 并行开发约束）、
  `coding-standards.md`。
- **延后（栈相关）**：`api-conventions`、`backend-conventions`、`database-conventions`、
  `frontend-conventions`、`styling-conventions`、`mcp-realtime-info`。

### 5.7 代理指南（`AGENTS.md` / `CLAUDE.md`）
- `AGENTS.md`：项目概述、仓库架构（AIWorkSpace）、子仓库操作、技术栈约束（标注"待定"）、
  目录结构、代理约束（工作流/规格/技能/已知问题/端口/并行开发）、质量门禁、斜杠命令表。
- `CLAUDE.md`：兼容入口，指向 `AGENTS.md`（避免双份维护）。

### 5.8 脚本（`scripts/`）
- `init-workspace.ps1`：幂等执行第 6 节初始化序列。
- `verify-structure.ps1`：校验目录/文件齐全、submodule 状态、`openspec validate`。

---

## 6. 初始化执行序列

> 因工作区已写入本设计文档（非空），主控仓库采用 `init + fetch + reset` 而非 `clone .`。

1. **引导版本库**：`git init -b main` → `git remote add origin <main-url>` → `git fetch origin`
   → `git reset --hard origin/main`（基于远端 main，保留其 README.md/LICENSE；未跟踪的 docs/ 共存）。
   > 已完成：本地 main 现处于 `666b546 Initial commit`，设计文档已提交于其上。
2. **添加子模块**：
   `git submodule add -b main <frontend-url> frontend`
   `git submodule add -b main <backend-url> backend`
3. **初始化 OpenSpec**：`openspec init --tools qoder`（生成 `openspec/` + `.qoder/commands/opsx/`）。
4. **Vendored Superpowers**：复制 7 个技能到 `.qoder/skills/`，附 `LICENSE` 与出处 `README.md`。
5. **写入治理层**：`.harness/`（guides+sensors+README）、`.qoder/agents/`、
   `.qoder/rules/`（workflow-conventions, coding-standards）、`.qoder/known-issues.md`、
   `.qoder/settings.json`、`AGENTS.md`、`CLAUDE.md`、`README.md`、`.gitignore`、`.gitattributes`、
   `scripts/`。
6. **自检门禁**：`openspec validate --all`；`scripts/verify-structure.ps1`。
7. **提交**：`git add -A` → 提交（约定式提交信息，如 `chore: bootstrap AI Workspace (SDD+harness+openspec)`）。
8. **推送**：`git push -u origin main`（含 submodule 指针；子仓库无本地改动则无需单独推送）。

---

## 7. 明确延后（暂不锁技术栈）

- frontend/backend 内的框架、构建脚本、`docker-compose.yml`、`.mcp/` 工具。
- 栈相关 `.qoder/rules/`（api/backend/database/frontend/styling/mcp）。
- Harness sensors 的具体检查命令（lint/test/build）——待栈锁定后经 OpenSpec 变更补齐。

---

## 8. 验证与质量门禁

- **结构验证**：`scripts/verify-structure.ps1` 检查关键路径存在、submodule 已注册。
- **规格验证**：`openspec validate --all` 通过。
- **命令可用性**：`.qoder/commands/opsx/` 下命令文件生成且 frontmatter 合法。
- **可复现性**：全新克隆 `git clone --recurse-submodules` 后结构完整、技能/命令就位。

---

## 9. 假设与风险

- **假设**：本地 git 凭据对三个仓库有读写权限（`git ls-remote` 已验证可读；主控仓库 API 404
  表明其为私有，但本地凭据可访问）。推送权限在实施时验证。
- **风险 1**：`openspec init` 版本差异可能改变生成路径 → 缓解：实施后以实际生成结果为准，
  `verify-structure.ps1` 做存在性校验。
- **风险 2**：Vendored 技能与全局插件 5.1.0 未来版本漂移 → 缓解：`skills/README.md` 记录来源版本。
- **风险 3**：子模块默认分支若为 `master` 而非 `main` → 缓解：`ls-remote` 已确认三仓均为 `main`。

---

## 10. 参考

- OpenSpec: https://github.com/Fission-AI/OpenSpec （已装 `@fission-ai/openspec@1.11.0`，原生支持 `--tools qoder`）
- Superpowers: https://github.com/obra/superpowers （全局插件 `superpowers@5.1.0`，MIT）
- 本地参考实现：`e:\workspace\my_first_sdd_project`（同架构既有项目，用作约定基准）
