# AGENTS.md — AI 代理指南

> 本文件为 AI 编码代理提供项目级别的指导和约束。**所有代理在本仓库工作前必须阅读本文件。**

## 项目概述

**AnanoesisShell** 是一个 AI 驱动的远程终端（AI-powered remote terminal）：用户无需记忆命令，由 AI 自动完成 Linux 运维操作。

本仓库当前已实现**本地 Web SSH + AI 核心流程**，采用 **Spec-Driven Development (SDD)** 方法论，融合三大 AI 编码工程理念：

1. **Harness 工程** — 通过 Guides（前馈控制）和 Sensors（反馈控制）约束 AI 代理行为
2. **OpenSpec** — 规格驱动开发，specs 作为真相源，changes 管理变更
3. **Superpowers** — 可组合技能（vendored 到 `.qoder/skills/`）增强 AI 代理纪律性

> 技术栈已由 `add-ssh-ai-agent-mvp` 变更及现有实现确立，见下方「技术栈选型约束」。桌面运行时与安装器尚未选定；不得擅自引入新业务框架或宣称 Windows 兼容已通过。

## 技术栈选型约束
- 前端：Vue3 + TypeScript + Vite + Pinia + Vue Router + xterm.js，原生 CSS 深色终端工作区。
- 后端：Java 17 编译基线 + Spring Boot 3.5 + Spring AI 1.1 + sshj；数据使用 MyBatis-Plus + SQLite(WAL) + Flyway，凭据使用 java-keyring + AES-GCM。具体版本以清单/锁文件为准。
- 契约：`contract/openapi.yaml` 生成 REST 接口/客户端；`contract/asyncapi.yaml` 约束手写 WS 类型与对齐测试。
- 远端仅支持 Linux 服务器；最终客户端只面向 Windows 7/10/11。当前仍是 Web MVP，安装包与各系统兼容性未完成验证，尤其 Win7 需要独立可行性评估。
- 公共、前端、后端、数据库与平台规范统一见 `.qoder/rules/`；规则是后续开发约束，不等于存量缺口已修复。

## 仓库架构（AI Workspace）

本项目采用 **主控仓库 + 子仓库** 的多仓库架构，通过 `git submodule` 管理前后端代码（均固定 `main` 分支）：

| 仓库 | 角色 | 远程地址 |
|------|------|---------|
| 主控仓库（本仓库） | SDD 方法论、规格、约束门禁、多代理编排、文档 | https://github.com/13198582183/AnanoesisShell.git |
| `frontend/` 子仓库 | 前端代码（Vue3 + TypeScript） | https://github.com/13198582183/AnanoesisShell-frontend.git |
| `backend/` 子仓库 | 后端代码（Spring Boot） | https://github.com/13198582183/AnanoesisShell-backend.git |

### 子仓库操作指南

```bash
# 首次克隆（含子仓库）
git clone --recurse-submodules https://github.com/13198582183/AnanoesisShell.git

# 初始化已有项目的子仓库
git submodule update --init --recursive

# 拉取子仓库远端最新（main 分支）
git submodule update --remote

# 进入子仓库独立开发（先切分支，勿在 detached HEAD 上提交）
cd frontend && git checkout main && git pull && git checkout -b feature/<name>

# 提交顺序：先子仓库 commit+push，再主控仓库记录指针
cd frontend && git add -A && git commit -m "feat: ..." && git push
cd .. && git add frontend backend && git commit -m "chore: update submodule refs"
```

### Worktree + 子仓库并行开发约束

> 详见 `.qoder/rules/workflow-conventions.md`。

**核心原则**：主仓库创建 worktree / feature 分支时，**子仓库必须同步创建同名分支**，禁止子仓库停留在 `main` 或 detached HEAD。合并 / 推送 / 清理时，必须对主仓库和所有子仓库执行完整闭环，禁止只处理主仓库。

## 目录结构

```
AnanoesisShell/
├── .harness/              # 约束系统
│   ├── guides/            # 前馈控制 — 工作流 / 编码规范
│   └── sensors/           # 反馈控制 — 质量 / 漂移检测
├── .gitmodules            # git submodule 配置（frontend / backend）
├── .qoder/                # Qoder IDE 配置
│   ├── commands/opsx/     # OpenSpec 原生斜杠命令（6 个）
│   ├── skills/            # 技能：6 个 OpenSpec（openspec-*）+ 8 个 Vendored Superpowers + LICENSE
│   ├── agents/            # 7 个栈无关角色子智能体
│   ├── rules/             # always_on 规则（工作流约定 / 编码规范）
│   └── known-issues.md    # 已知问题与 Bug 记录（开发前必读）
├── openspec/              # 规格驱动开发
│   ├── specs/             # 规格文件（真相源）
│   └── changes/           # 变更提案（含 archive/）
├── frontend/              # [子仓库] 前端（Vue3 + TypeScript）
├── backend/               # [子仓库] 后端（Spring Boot）
├── scripts/               # 初始化 / 结构校验脚本（PowerShell）
├── docs/                  # 设计文档与实施计划
├── AGENTS.md              # 本文件
├── CLAUDE.md              # Claude 代理入口（指向本文件）
└── README.md              # 项目说明
```

## 代理约束

### 必须遵循

1. **工作流约束**（来自 `.harness/guides/`）
   - 所有开发任务必须遵循 Explore → Plan → Implement → Verify → Complete 流程
   - 不得跳过 brainstorming 阶段直接实现
   - 不得在无测试的情况下提交实现代码
   - 不得在验证前声称任务完成

2. **规格约束**（来自 `openspec/specs/`）
   - specs 是系统行为的唯一真相源；所有实现必须对照 spec 验证
   - 所有变更必须通过 OpenSpec 变更流程（`/opsx:propose` → `/opsx:apply` → `/opsx:archive`）管理

3. **技能约束**（来自 `.qoder/skills/`）
   - 在相应场景必须触发对应技能（见下表）；技能中定义的规则为强制约束

4. **已知问题约束**（来自 `.qoder/known-issues.md`）
   - **开发前**：开始新功能或修改前，必须先阅读 `.qoder/known-issues.md`
   - **遇到问题时**：优先查阅已知问题文档，避免重复踩坑
   - **解决问题后**：将新发现的问题补充进 `known-issues.md`（症状 / 原因 / 解决方案 / 预防措施）

5. **技术栈约束**
   - 遵守上方已落地的技术栈基线，禁止擅自替换框架或引入未经评估的依赖
   - 后续技术栈/桌面运行时选型必须通过 OpenSpec 决定，并同步「技术栈选型约束」与 `.qoder/rules/`

### 质量门禁（来自 `.harness/sensors/`）

- 所有测试必须通过；Spec 中的所有场景必须有对应实现
- 代码必须通过 code review；完成前必须提供验证证据（命令 + 输出）
- 结构变更必须通过 `scripts/verify-structure.ps1`

## 技能触发场景（`.qoder/skills/`）

| 场景 | 必须触发的技能 |
|------|---------------|
| 需求 / 设计澄清 | brainstorming |
| 编写实施计划 | writing-plans |
| 执行实施计划 | executing-plans |
| 实现功能 / 修复 | test-driven-development |
| 排查 bug / 测试失败 | systematic-debugging |
| 发起代码评审 | requesting-code-review |
| 处理评审意见 | receiving-code-review |
| 声称完成前 | verification-before-completion |

## 斜杠命令（OpenSpec 原生，定义在 `.qoder/commands/opsx/`）

| 命令 | 说明 |
|------|------|
| `/opsx:explore` | 探索一个主题 / 需求（变更前的思考伙伴，澄清问题） |
| `/opsx:propose` | 提出变更（一步生成 proposal / design / specs / tasks） |
| `/opsx:apply` | 实施已批准的变更（逐任务实现） |
| `/opsx:sync` | 将变更的 delta specs 同步回主 specs（智能合并，不归档变更） |
| `/opsx:update` | 修订变更的规划工件并保持彼此一致（不改代码） |
| `/opsx:archive` | 归档已完成的变更并更新 specs |

> 命令集以 `openspec init` 实际生成、`.qoder/commands/opsx/` 下的文件为准（当前 OpenSpec 1.11.0 生成 6 个命令，各命令对应一个 `openspec-*` 技能）。
