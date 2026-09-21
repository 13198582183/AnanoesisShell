# AnanoesisShell AI Workspace 初始化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在空工作区初始化 AI Workspace 多仓架构（主控仓库 + `frontend/`、`backend/` 两个 git submodule），落地 OpenSpec + Harness + Vendored Superpowers 的治理骨架，暂不锁定业务技术栈。

**Architecture:** 主控仓库是"控制面"（规格 / 约束门禁 / 多代理编排 / 文档），`frontend/`、`backend/` 是"代码面"（独立仓库，submodule 固定指针）。OpenSpec 集中式规格 + 原生 Qoder 斜杠命令；Harness 用 guides（前馈）/ sensors（反馈）做门禁；Superpowers 技能以固定副本 vendored 到 `.qoder/skills/`。

**Tech Stack:** Git(submodules) · Node 22 + `@fission-ai/openspec@1.11.0` · Qoder（`.qoder/` commands/skills/agents/rules）· PowerShell 脚本 · Superpowers 5.1.0 (MIT)。业务前后端栈**待定**（后续经 OpenSpec 变更锁定）。

---

## 前置状态（已完成，无需重做）

- 工作区 `f:\project\dev\workspace\AnanoesisShell` 已 `git init -b main`，`origin` = `https://github.com/13198582183/AnanoesisShell.git`。
- 已 `git reset --hard origin/main`：本地含远端 `README.md`（产品说明）+ `LICENSE`（MIT）。
- 设计文档已提交：`29334d4 docs: add AI Workspace initialization design spec`。
- 三个远端仓库默认分支均为 `main`。

## 全局执行注意

- **Shell**：Windows PowerShell 5.1，语句分隔用 `;`（不支持 `&&`）。
- **沙箱**：`git` 的写/网络操作（init/fetch/submodule/commit/push）可能被沙箱拒绝执行；如报 `git.exe 无法运行: 拒绝访问`，以"运行于沙箱外/提升权限"重试。
- **提交**：全局已配置 `user.name=liziwen`、`user.email=xisoemail@163.com`，可直接 `git commit`。
- **不推送**：Task 1–9 仅本地提交；`git push` 在 Task 10 且需用户明确确认后执行。
- **约定式提交**：`feat/fix/docs/chore` 前缀。

## 文件结构映射（本次将创建/修改）

```
AnanoesisShell/
├── .gitmodules                         [Task1 创建] submodule: frontend, backend
├── frontend/                           [Task1 submodule] → AnanoesisShell-frontend.git
├── backend/                            [Task1 submodule] → AnanoesisShell-backend.git
├── openspec/                           [Task2 生成] 集中式规格
├── .qoder/
│   ├── commands/opsx/*.md              [Task2 生成] /opsx:explore|propose|apply|sync|update|archive（6 个）
│   ├── skills/                         [Task2+Task3] 6 个 OpenSpec(openspec-*) + 8 个 Superpowers(vendored) + LICENSE + README
│   ├── rules/workflow-conventions.md   [Task5]
│   ├── rules/coding-standards.md       [Task5]
│   ├── agents/*.md                     [Task6] 7 个栈无关角色
│   └── known-issues.md                 [Task7]
├── .harness/
│   ├── README.md                       [Task4]
│   ├── guides/workflow.md              [Task4]
│   ├── guides/coding-standards.md      [Task4]
│   ├── sensors/quality.md              [Task4]
│   └── sensors/drift-detection.md      [Task4]
├── .gitignore                          [Task8]
├── .gitattributes                      [Task8]
├── AGENTS.md                           [Task8]
├── CLAUDE.md                           [Task8]
├── README.md                           [Task8 扩写，保留产品说明]
├── scripts/init-workspace.ps1          [Task9]
├── scripts/verify-structure.ps1        [Task9]
└── docs/superpowers/{specs,plans}/     [已存在]
```

> 说明：相对设计文档的两处细化 —— (1) vendored 技能为 **8 个**（v5.1.0 中 `code-review` 拆分为 `requesting-code-review` + `receiving-code-review`）；(2) **不创建** `.qoder/settings.json`（原生命令无需启用插件）。

---

## Task 1: 添加 frontend / backend 子模块

**Files:**
- Create: `.gitmodules`（由 `git submodule add` 生成）
- Create: `frontend/`（submodule gitlink）
- Create: `backend/`（submodule gitlink）

- [ ] **Step 1: 添加前端子模块**

Run:
```powershell
cd f:\project\dev\workspace\AnanoesisShell
git submodule add -b main https://github.com/13198582183/AnanoesisShell-frontend.git frontend
```
Expected: 克隆 `frontend/`（含其 README.md），生成/更新 `.gitmodules`。

- [ ] **Step 2: 添加后端子模块**

Run:
```powershell
git submodule add -b main https://github.com/13198582183/AnanoesisShell-backend.git backend
```
Expected: 克隆 `backend/`（含其 README.md），`.gitmodules` 追加 backend 段。

- [ ] **Step 3: 验证子模块状态**

Run:
```powershell
git submodule status
Get-Content .gitmodules
```
Expected: 两行 submodule 状态（前缀非 `-`，表示已初始化），`.gitmodules` 含 `[submodule "frontend"]` 与 `[submodule "backend"]`，各带 `path`、`url`、`branch = main`。

- [ ] **Step 4: 提交**

```powershell
git add .gitmodules frontend backend
git commit -m "chore: add frontend/backend as git submodules (main branch)"
```

---

## Task 2: 初始化 OpenSpec（原生 Qoder 命令）

**Files:**
- Create: `openspec/`（specs/、changes/、project 元数据等，由 CLI 生成）
- Create: `.qoder/commands/opsx/*.md`（`/opsx:explore|propose|apply|sync|update|archive`，共 6 个）

- [ ] **Step 1: 运行 openspec init（非交互）**

Run:
```powershell
cd f:\project\dev\workspace\AnanoesisShell
openspec init --tools qoder --no-animation --force --no-copilot-cloud
```
Expected: 输出初始化成功；生成 `openspec/` 与 `.qoder/commands/opsx/`。`--force` 跳过 legacy 清理确认，`--no-copilot-cloud` 跳过 Copilot 云确认，`--tools qoder` 跳过工具选择交互。

- [ ] **Step 2: 记录实际生成结构（用于校准后续引用）**

Run:
```powershell
Get-ChildItem openspec -Recurse -Force | ForEach-Object { $_.FullName.Substring((Get-Location).Path.Length) }
Get-ChildItem .qoder\commands\opsx -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
```
Expected: `openspec/` 含 `specs/`、`changes/`（及 CLI 生成的元数据文件）；`.qoder/commands/opsx/` 含 6 个 `.md`（explore/propose/apply/sync/update/archive）。OpenSpec 1.11.0 同时在 `.qoder/skills/` 生成 6 个 `openspec-*` 技能，并写入 `openspec/config.yaml`（schema: spec-driven），不生成 `schemas/`。**命令集以本步实际输出为准，Task8 的 AGENTS.md 斜杠命令表已按 6 命令校准。**

- [ ] **Step 3: 验证 openspec 可用**

Run:
```powershell
openspec list
openspec validate --all
```
Expected: `openspec list` 正常返回（空变更列表亦可）；`openspec validate --all` 无错误退出（exit 0）。

- [ ] **Step 4: 提交**

```powershell
git add openspec .qoder/commands
git commit -m "feat: initialize OpenSpec with native Qoder /opsx commands"
```

---

## Task 3: Vendor Superpowers 技能到 .qoder/skills/

**Files:**
- Create: `.qoder/skills/{brainstorming,writing-plans,executing-plans,test-driven-development,systematic-debugging,verification-before-completion,requesting-code-review,receiving-code-review}/`（从全局插件缓存复制）
- Create: `.qoder/skills/LICENSE`（源插件 MIT 许可证）
- Create: `.qoder/skills/README.md`（出处与版本标注）

- [ ] **Step 1: 复制 8 个技能目录 + LICENSE**

Run:
```powershell
$src = "$env:USERPROFILE\.qoder\plugins\cache\qoder-marketplace\superpowers\5.1.0"
$dst = "f:\project\dev\workspace\AnanoesisShell\.qoder\skills"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
$skills = @("brainstorming","writing-plans","executing-plans","test-driven-development","systematic-debugging","verification-before-completion","requesting-code-review","receiving-code-review")
foreach ($s in $skills) { Copy-Item -Recurse -Force "$src\skills\$s" "$dst\$s" }
Copy-Item -Force "$src\LICENSE" "$dst\LICENSE"
```
Expected: `.qoder/skills/` 下新增 8 个 Superpowers 技能目录（各含 `SKILL.md`）+ `LICENSE`；连同 Task2 生成的 6 个 `openspec-*` 技能，共 14 个技能目录。

- [ ] **Step 2: 写入 `.qoder/skills/README.md`**

Create `.qoder/skills/README.md`:
````text
# Vendored Superpowers Skills

本目录为 [Superpowers](https://github.com/obra/superpowers) 技能的**固定副本**（vendored），
用于保证所有贡献者环境一致、可复现、离线可用。

- **来源**：全局插件 `superpowers@5.1.0`（`~/.qoder/plugins/cache/qoder-marketplace/superpowers/5.1.0/skills/`）
- **许可证**：MIT（见同目录 `LICENSE`）
- **升级方式**：手动同步（见 `scripts/init-workspace.ps1` 注释），升级后更新本文件的版本号

## 已固定技能（8）

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

> 技能的"发现与触发"由 `AGENTS.md` 与 `.qoder/rules/workflow-conventions.md` 强制约束，
> 替代全局插件的 SessionStart 钩子作用。
````

- [ ] **Step 3: 验证**

Run:
```powershell
Get-ChildItem f:\project\dev\workspace\AnanoesisShell\.qoder\skills -Directory | Select-Object -ExpandProperty Name
Test-Path f:\project\dev\workspace\AnanoesisShell\.qoder\skills\brainstorming\SKILL.md
```
Expected: 列出 14 个技能目录（6 个 `openspec-*` + 8 个 Superpowers）；`Test-Path` 返回 `True`。

- [ ] **Step 4: 提交**

```powershell
git add .qoder/skills
git commit -m "chore: vendor Superpowers 5.1.0 skills into .qoder/skills (MIT)"
```

---

## Task 4: 建立 Harness 约束系统（.harness/）

**Files:**
- Create: `.harness/README.md`
- Create: `.harness/guides/workflow.md`
- Create: `.harness/guides/coding-standards.md`
- Create: `.harness/sensors/quality.md`
- Create: `.harness/sensors/drift-detection.md`

- [ ] **Step 1: 写入 `.harness/README.md`**

````text
# Harness — 约束系统

> 通过 Guides（前馈控制）与 Sensors（反馈控制）约束 AI 代理行为，是 SDD 的落地门禁层。

## 结构

    .harness/
    ├── README.md               # 本文件
    ├── guides/                 # 前馈控制：代理行动前注入约束
    │   ├── workflow.md         # 开发工作流 Explore→Plan→Implement→Verify→Complete
    │   └── coding-standards.md # 编码与注释规范
    └── sensors/                # 反馈控制：代理行动后校验
        ├── quality.md          # 质量门禁检查点
        └── drift-detection.md  # Spec 漂移检测

## Guides（前馈控制）
在代理开始任务**前**注入上下文与约束，防止偏差发生。

## Sensors（反馈控制）
在代理完成行动**后**检查输出，检测并纠正偏差；未通过门禁禁止合并 / 归档。

## 使用方式
`AGENTS.md` / `CLAUDE.md` 引用本目录：遵循 `guides/`，对照 `sensors/` 校验。
````

- [ ] **Step 2: 写入 `.harness/guides/workflow.md`**

````text
# Workflow Guide — 开发工作流前馈控制

所有 AI 代理在开始开发任务前，必须遵循以下工作流：

## 1. 探索 (Explore)
- 理解需求，阅读相关 specs（`openspec/specs/`）
- 使用 brainstorming 技能澄清意图
- 检查现有代码与架构；开发前阅读 `.qoder/known-issues.md`

## 2. 规划 (Plan)
- 使用 writing-plans 技能创建实施计划
- 任务分解为可独立验证的小步骤，每步有明确完成标准

## 3. 实现 (Implement)
- 使用 test-driven-development 技能，遵循 RED → GREEN → REFACTOR
- 先写测试再写实现；遵循 coding-standards，在关键处注释业务意图（WHY）

## 4. 验证 (Verify)
- 使用 verification-before-completion 技能，运行全部测试
- 使用 requesting-code-review / receiving-code-review 技能进行评审

## 5. 完成 (Complete)
- 更新相关 specs，通过 /opsx:archive 归档变更，提交代码

## 约束规则
- [ ] 不得跳过 brainstorming 阶段直接实现
- [ ] 不得在没有测试的情况下提交实现代码
- [ ] 不得在验证前声称任务完成
- [ ] 所有变更必须通过 openspec 变更流程管理
````

- [ ] **Step 3: 写入 `.harness/guides/coding-standards.md`**

````text
# Coding Standards Guide — 编码规范前馈控制

重点要求：在关键位置编写注释，解释代码的业务逻辑意图。
注释传达意图（WHY），代码表达行为（WHAT）。

## 1. 注释原则
- 注释解释 WHY，代码表达 WHAT（业务动机、设计决策、约束原因）
- 注释必须与代码同步更新
- 禁止无意义注释（重复代码语义）
- 统一使用中文注释

## 2. 必须添加注释的位置
- 类 / 模块级别：职责说明 + 关键设计决策
- 公共方法 / 接口：业务目的、关键参数语义、返回值含义、异常场景
- 关键业务逻辑块：实现的业务规则 + 为何这样实现
- 非显而易见的技术决策：特殊技巧 / 绕过方案的原因
- TODO / FIXME：上下文（为何现状如此）+ 期望（未来应如何）

## 3. 不需要注释的位置
- 自解释的简单赋值、getter / setter；已有文档注释的接口实现；方法名已表达意图的测试

## 4. 自检清单
- [ ] 每个业务类 / 模块有职责说明
- [ ] 每个公共方法有业务目的说明
- [ ] 关键业务规则处解释了 WHY
- [ ] 非显而易见的技术决策有原因说明
- [ ] 注释使用中文、清晰、与代码同步、无冗余

> 注：语言 / 框架特定格式规范（Javadoc、JSDoc、SQL COMMENT 等）在锁定技术栈后，
> 通过 openspec 变更补充到本文件与 `.qoder/rules/coding-standards.md`。
````

- [ ] **Step 4: 写入 `.harness/sensors/quality.md`**

````text
# Quality Sensor — 质量反馈控制

AI 代理在以下节点必须执行质量检查：

## 代码提交前
- [ ] 所有测试通过（单元 + 集成）
- [ ] 代码符合编码规范（见 guides/coding-standards.md）
- [ ] 无安全漏洞引入
- [ ] 变更与 spec 要求一致
- [ ] 关键业务逻辑有注释说明意图

## Spec 合规性
- [ ] 实现覆盖 spec 中所有需求
- [ ] 所有场景（scenarios）都有对应测试
- [ ] 未引入 spec 未定义的行为

## 架构一致性
- [ ] 新增代码遵循现有架构模式
- [ ] 模块边界清晰，无循环依赖
- [ ] 接口与 design.md 一致

## 质量门禁（未通过禁止合并）
1. 测试未全部通过
2. 存在未解决的 code review 问题
3. Spec 场景未被完全实现
4. 引入未记录的破坏性变更
5. 关键业务逻辑缺少注释
6. Spec 漂移检查未通过（见 drift-detection.md）

> 注：量化阈值（如覆盖率 ≥ 80%）与具体校验命令（lint / test / build）在锁定技术栈后补充。
````

- [ ] **Step 5: 写入 `.harness/sensors/drift-detection.md`**

````text
# Drift Detection Sensor — Spec 漂移检测

> 变更级 Spec 漂移检查，在 /opsx:apply 完成后、归档前触发。

## 触发时机
每次 /opsx:apply <change-name> 所有任务完成后、归档前必须执行本 Sensor。

## 检查流程
### Step 1 识别涉及的 Spec
读取 openspec/changes/<change-name>/ 下 specs，提取 ADDED / MODIFIED / REMOVED Requirements，
定位对应 openspec/specs/<module>/ 文件。

### Step 2 逐场景对照
对每个 Requirement 的每个 Scenario：提取 GIVEN / WHEN / THEN → 定位代码实现 → 判定：
对齐 / 漂移（代码与 spec 不一致）/ 缺失（无实现）。

### Step 3 输出偏差清单
以 Markdown 表格输出每个场景的对齐状态。

### Step 4 以代码为准更新 Spec
漂移 → 更新 spec 与代码一致（代码是真相源）；缺失 → 补实现或更新 spec 并标注原因；更新后重新对照。

### Step 5 确认无漂移
全部对齐后，在 tasks.md 底部记录检查时间与结果。

## 检查范围
| 检查项 | 说明 |
|--------|------|
| 接口路径 / 契约 | spec 定义的端点 / 接口与实现一致 |
| 数据结构 | spec 定义字段与实际数据结构一致 |
| 业务规则 | spec 的 THEN 条件与代码行为一致 |
| 错误处理 | spec 定义的错误码 / 状态与实现一致 |
| 边界条件 | spec 描述的边界行为与代码一致 |
````

- [ ] **Step 6: 验证 + 提交**

Run:
```powershell
Get-ChildItem f:\project\dev\workspace\AnanoesisShell\.harness -Recurse -File | ForEach-Object { $_.FullName.Substring((Get-Location).Path.Length) }
git add .harness
git commit -m "feat: add harness constraint system (guides + sensors)"
```
Expected: 列出 5 个 `.md`（README + guides/2 + sensors/2）；提交成功。

---

## Task 5: 建立 .qoder/rules（工作流 + 编码规范）

**Files:**
- Create: `.qoder/rules/workflow-conventions.md`
- Create: `.qoder/rules/coding-standards.md`

- [ ] **Step 1: 写入 `.qoder/rules/workflow-conventions.md`**

````text
---
trigger: always_on
alwaysApply: true
---

# Workflow Conventions — 开发工作流规范

## 1. 开发流程（Explore → Plan → Implement → Verify → Complete）
- **Explore**：理解需求，阅读 `openspec/specs/`；用 brainstorming 技能澄清；开发前读 `.qoder/known-issues.md`
- **Plan**：用 writing-plans 技能制定计划，任务拆成可独立验证的小步
- **Implement**：用 test-driven-development 技能，RED→GREEN→REFACTOR；遵循 coding-standards
- **Verify**：用 verification-before-completion 跑全部测试；用 requesting / receiving-code-review 评审
- **Complete**：更新 specs，/opsx:archive 归档，提交

## 2. 约束规则
- 不得跳过 brainstorming 直接实现
- 不得在无测试情况下提交实现代码
- 不得在验证前声称完成
- 所有变更必须经 openspec 变更流程

## 3. 质量门禁（提交前）
- [ ] 所有测试通过
- [ ] 符合编码规范
- [ ] 无安全漏洞引入
- [ ] 变更与 spec 一致
- [ ] 关键业务逻辑有注释

## 4. 禁止合并的情况
1. 测试未全部通过
2. 存在未解决的 code review 问题
3. spec 场景未完全实现
4. 引入未记录的破坏性变更
5. 关键业务逻辑缺少注释
6. Spec 漂移检查未通过（见 `.harness/sensors/drift-detection.md`）

## 5. Worktree + 子仓库并行开发（强制）
主仓库用 `git worktree` 并行开发时，**子仓库必须同步创建同名 feature 分支**，禁止停留在 `main`。

### 5.1 创建 worktree 时同步子仓库分支

    git worktree add ../AnanoesisShell-feat-x feature/feat-x
    cd ../AnanoesisShell-feat-x
    cd frontend && git fetch origin && git checkout -b feature/feat-x origin/main && cd ..
    cd backend  && git fetch origin && git checkout -b feature/feat-x origin/main && cd ..

### 5.2 进入 worktree 必检子仓库分支

    cd frontend && git branch --show-current && cd ..
    cd backend  && git branch --show-current && cd ..

若子仓库不在对应 feature 分支，必须立即切换或按 5.1 创建。

### 5.3 合并闭环（Check → Merge → Clean）
- **Check**：在 feature 工作区跑全量验证（栈锁定后补具体命令）
- **Merge**：先子仓库（frontend / backend 各自 merge main、解决冲突、push feature），
  再主仓库（merge feature → `git add frontend backend` → commit 更新指针）
- **Clean**：push 主仓库；删除三仓的 worktree、本地 feature 分支、远端 feature 分支

### 5.4 禁止事项
- 禁止主仓库建 worktree 而子仓库停留在 main
- 禁止只合并 / 推送 / 清理主仓库而忽略子仓库
- 禁止未 Check 直接 Merge、Merge 后不验证直接 push
- 禁止在 feature 工作区直接 push 到 main

> 栈相关的验证命令（build / lint / test）在锁定技术栈后经 openspec 变更补充到第 5.3 节。
````

- [ ] **Step 2: 写入 `.qoder/rules/coding-standards.md`**

````text
---
trigger: always_on
alwaysApply: true
---

# Coding Standards — 编码规范（核心约束）

> 详细规范见 `.harness/guides/coding-standards.md`；本文件为始终注入的核心摘要。

## 强制规则
- **注释解释 WHY，代码表达 WHAT**：注释说明业务动机 / 设计决策 / 约束原因，不复述语法
- **统一中文注释**；修改代码必须同步更新注释
- **禁止无意义注释**（如 `// 获取用户` 复述 `getUser()`）
- 必须注释：类 / 模块职责、公共方法业务目的与参数 / 返回 / 异常语义、关键业务规则、
  非显而易见的技术决策、TODO / FIXME（含上下文与期望）

## 通用工程约束
- DRY / YAGNI；小步提交；文件职责单一
- 错误必须显式处理，禁止吞异常
- 命名清晰自解释，避免歧义缩写

> 语言 / 框架特定格式（Javadoc / JSDoc / SQL COMMENT 等）在锁定技术栈后经 openspec 变更补充。
````

- [ ] **Step 3: 验证 + 提交**

Run:
```powershell
Get-ChildItem f:\project\dev\workspace\AnanoesisShell\.qoder\rules -File | Select-Object -ExpandProperty Name
git add .qoder/rules
git commit -m "feat: add qoder rules (workflow-conventions, coding-standards)"
```
Expected: 列出 `coding-standards.md`、`workflow-conventions.md`；提交成功。

---

## Task 6: 建立 .qoder/agents（7 个栈无关角色）

**Files:**
- Create: `.qoder/agents/{product-manager,architect,frontend-engineer,backend-engineer,qa-engineer,code-reviewer,task-dispatcher}.md`

> 说明：frontmatter 的 `rules:` 仅引用已存在的规则（workflow-conventions、coding-standards）；
> `skills:` 仅引用已 vendored 的技能。frontend/backend 工程师为栈无关骨架，锁定技术栈后经 openspec 变更细化。

- [ ] **Step 1: 写入 `.qoder/agents/product-manager.md`**

````text
---
name: product-manager
description: 产品经理子智能体，负责需求澄清、PRD 定义与产品合理性审核。需求模糊或 /opsx:explore、/opsx:propose 阶段触发，不直接编码。
tools: Read, Grep, Glob, Write
skills:
  - brainstorming
rules:
  - workflow-conventions
---

# 角色定义
你是产品经理（Product Manager）子智能体，把模糊想法转化为清晰、可验证的需求。

## 核心职责
- 需求澄清：用 brainstorming 追问目的、约束、成功标准
- 编写 / 审核 proposal.md：动机、变更范围、预期结果
- 定义验收标准：每个需求配可测场景（GIVEN/WHEN/THEN）
- 产品合理性审核：识别 Scope Creep，拒绝超出 spec 的功能

## 触发条件
- 需求模糊 / 边界不清 / PRD 缺失
- /opsx:explore、/opsx:propose 阶段需要产品视角输入

## 输出契约
- 结构化需求说明 + 验收场景（写入 openspec/changes/<name>/proposal.md）

## MUST NOT
- 禁止编写实现代码；禁止在无明确需求时臆造功能
````

- [ ] **Step 2: 写入 `.qoder/agents/architect.md`**

````text
---
name: architect
description: 架构师子智能体，负责系统架构设计与技术决策，确保方案与 spec 一致。/opsx:explore、/opsx:propose 阶段提供可行性分析与边界划分，不直接编码。
tools: Read, Grep, Glob, Write
skills:
  - writing-plans
rules:
  - workflow-conventions
  - coding-standards
---

# 角色定义
你是架构师（Architect）子智能体，负责整体技术方案与架构决策，基于 SDD 确保方案与规格一致。

## 核心职责
- 技术方案规划：模块划分、数据流、接口契约
- 边界划分：明确前后端职责边界
- 技术选型：评估可行性与风险（本项目技术栈待定，选型须经 openspec 变更固化）
- 架构决策记录（ADR）：说明 WHY 与权衡

## 触发条件
- 新模块设计 / 跨模块变更 / 技术选型
- /opsx:explore 需可行性分析、/opsx:propose 需审核 design.md

## 输出契约
- 架构设计方案（模块划分、数据流、接口契约、风险表）写入 design.md

## MUST NOT
- 禁止直接修改代码（仅通过文档与评审指导）；禁止在无 spec 情况下设计方案
````

- [ ] **Step 3: 写入 `.qoder/agents/frontend-engineer.md`**

````text
---
name: frontend-engineer
description: 前端工程师子智能体，负责 frontend/ 子仓库的页面、组件与 API 集成实现。技术栈锁定后细化；当前遵循 SDD 与 TDD 纪律。
tools: Read, Grep, Glob, Write, Edit, Bash
skills:
  - test-driven-development
  - systematic-debugging
  - verification-before-completion
rules:
  - workflow-conventions
  - coding-standards
---

# 角色定义
你是前端工程师（Frontend Engineer）子智能体，负责 `frontend/` 子仓库的实现。

## 核心职责
- 按 spec 与 design.md 实现页面 / 组件 / 状态 / API 集成
- 遵循 TDD（RED→GREEN→REFACTOR），先写测试
- 在 frontend/ 子仓库内独立提交，再由主仓库更新指针

## 触发条件
- /opsx:apply 阶段的前端任务；前端 Bug 修复

## 输出契约
- 通过测试的实现代码 + 对应测试；关键业务逻辑有中文注释（WHY）

## 待细化
- 具体框架 / 构建 / 测试命令在技术栈锁定后经 openspec 变更补充

## MUST NOT
- 禁止在无 spec / 无测试情况下提交；禁止越界修改 backend/
````

- [ ] **Step 4: 写入 `.qoder/agents/backend-engineer.md`**

````text
---
name: backend-engineer
description: 后端工程师子智能体，负责 backend/ 子仓库的 API、服务层与数据访问实现。技术栈锁定后细化；当前遵循 SDD 与 TDD 纪律。
tools: Read, Grep, Glob, Write, Edit, Bash
skills:
  - test-driven-development
  - systematic-debugging
  - verification-before-completion
rules:
  - workflow-conventions
  - coding-standards
---

# 角色定义
你是后端工程师（Backend Engineer）子智能体，负责 `backend/` 子仓库的实现。

## 核心职责
- 按 spec 与 design.md 实现接口 / 服务层 / 数据访问
- 遵循 TDD（RED→GREEN→REFACTOR），先写测试
- 在 backend/ 子仓库内独立提交，再由主仓库更新指针

## 触发条件
- /opsx:apply 阶段的后端任务；后端 Bug 修复

## 输出契约
- 通过测试的实现代码 + 对应测试；关键业务逻辑有中文注释（WHY）

## 待细化
- 具体框架 / ORM / 构建 / 测试命令在技术栈锁定后经 openspec 变更补充

## MUST NOT
- 禁止在无 spec / 无测试情况下提交；禁止越界修改 frontend/
````

- [ ] **Step 5: 写入 `.qoder/agents/qa-engineer.md`**

````text
---
name: qa-engineer
description: 测试工程师子智能体，负责测试用例设计与执行、回归验证。/opsx:apply、/opsx:archive 阶段触发。
tools: Read, Grep, Glob, Write, Bash
skills:
  - test-driven-development
  - verification-before-completion
rules:
  - workflow-conventions
---

# 角色定义
你是测试工程师（QA Engineer）子智能体，保障实现与 spec 场景一致且可回归。

## 核心职责
- 依据 spec 场景设计测试用例（覆盖正常 / 边界 / 异常）
- 执行测试并报告结果；回归验证已修复问题
- 维护测试可重复性与独立性

## 触发条件
- /opsx:apply 需要测试设计与编写；/opsx:archive 需要回归验证

## 输出契约
- 测试用例 + 执行报告（通过 / 失败 / 覆盖的 spec 场景）

## MUST NOT
- 禁止在无 spec 场景依据时臆造测试；禁止谎报测试结果
````

- [ ] **Step 6: 写入 `.qoder/agents/code-reviewer.md`**

````text
---
name: code-reviewer
description: 代码评审专家子智能体，负责 Spec 合规评审 + 代码质量评审。提交前与归档前触发。
tools: Read, Grep, Glob
skills:
  - requesting-code-review
  - receiving-code-review
rules:
  - workflow-conventions
  - coding-standards
---

# 角色定义
你是代码评审专家（Code Reviewer）子智能体，保障代码与 spec 对齐且符合质量门禁。

## 核心职责
- Spec 合规评审：实现是否覆盖 spec 全部场景、有无越界行为
- 质量评审：可读性、边界、错误处理、安全、注释（WHY）
- 对照 `.harness/sensors/quality.md` 与 `drift-detection.md` 出具结论

## 触发条件
- 代码提交前；/opsx:archive 归档前的最终审查

## 输出契约
- 评审问题清单（严重程度 / 位置 / 建议），并给出通过 / 阻塞结论

## MUST NOT
- 禁止直接改代码（只评审）；禁止放过未解决的阻塞问题
````

- [ ] **Step 7: 写入 `.qoder/agents/task-dispatcher.md`**

````text
---
name: task-dispatcher
description: 任务分派指挥官，分析需求/Spec/评审反馈，将任务路由到对应专业智能体并排序。只分派不执行。
tools: Read, Grep, Glob
skills:
  - executing-plans
  - brainstorming
rules:
  - workflow-conventions
---

# 角色定义
你是任务分派指挥官（Task Dispatcher），把问题/需求/Spec 转化为可执行分派方案，路由到专业智能体。
核心信条：你是指挥官，不是执行者，只分析/拆解/分派，不写代码。

## 可调度智能体
| 智能体 | 职责 | 触发 |
|--------|------|------|
| product-manager | 需求澄清/PRD | 需求模糊 |
| architect | 架构/技术方案 | 新模块/选型 |
| frontend-engineer | 前端实现 | 页面/组件 |
| backend-engineer | 后端实现 | API/服务 |
| qa-engineer | 测试设计/执行 | 功能/回归 |
| code-reviewer | Spec 合规+质量评审 | 提交前/归档前 |

## OpenSpec 阶段路由
- /opsx:explore → product-manager, architect
- /opsx:propose → architect(design), product-manager(proposal 审核)
- /opsx:apply → backend/frontend-engineer(实现), qa-engineer(测试)
- /opsx:archive → code-reviewer(评审), qa-engineer(回归)

## 输出契约
结构化分派方案：输入分析 + 分派指令（目标智能体/任务/关联 spec/预期输出/验收标准）+ 执行顺序 + 并行组

## MUST NOT
- 禁止自己写代码；禁止跳过 spec 分析直接分派；禁止需求不清时强行分派（先派 product-manager）
````

- [ ] **Step 8: 验证 + 提交**

Run:
```powershell
Get-ChildItem f:\project\dev\workspace\AnanoesisShell\.qoder\agents -File | Select-Object -ExpandProperty Name
git add .qoder/agents
git commit -m "feat: add 7 stack-agnostic qoder subagents"
```
Expected: 列出 7 个 `.md`；提交成功。

---

## Task 7: 建立已知问题库（.qoder/known-issues.md）

**Files:**
- Create: `.qoder/known-issues.md`（模板 + 2 条栈无关种子条目）

> 该文件是 Harness 前馈控制的一部分：`AGENTS.md` 要求代理**开发前必读**、**解决问题后必须补充**。种子条目选取与本工作区强相关、且**不依赖任何业务技术栈**的 Windows/Git 陷阱。

- [ ] **Step 1: 写入 `.qoder/known-issues.md`**

````text
# 已知问题记录（Known Issues）

> 本文档记录项目开发过程中遇到的 bug、错误和解决方案，避免后续重复踩坑。
> **开发前必读**；**解决问题后必须补充**（症状 / 根本原因 / 解决方案 / 预防措施）。

---

## 记录规范

每条问题按以下结构记录（编号递增）：

    ## N. <一句话标题>
    **发现时间**: YYYY-MM-DD
    **影响范围**: <受影响的模块/流程>
    **症状**: <可观测到的错误表现>
    **根本原因**: <为什么会发生>
    **解决方案**: <如何修复，含命令/代码>
    **预防措施**: <如何避免再次发生>

---

## 1. PowerShell 管道向原生程序传输中文被 GBK 重编码破坏

**发现时间**: 2026-09-20
**影响范围**: Windows PowerShell 5.1 下，任何把含中文的文本经管道 `|` 喂给原生程序（git / 数据库客户端 / cli）的场景
**症状**: `Get-Content file.txt -Raw -Encoding UTF8 | some-native-exe` 执行后，中文变成 `??` 或乱码；但直接读取文件内容显示正常
**根本原因**: PowerShell 把管道数据传给原生程序时，会按 `$OutputEncoding` / 控制台 OEM 代码页（中文系统为 GBK/936）重新编码字节流，UTF-8 的多字节中文被破坏。
**解决方案**:
- 会话内临时切换 UTF-8：`chcp 65001; $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8`
- 避免用管道把中文喂给原生程序，改用「文件中转 + 程序自身读取」或参数传递
- 永久修复：Windows 设置开启 “Beta: 使用 Unicode UTF-8 提供全球语言支持”，或改用 Windows Terminal
**预防措施**: Windows 下处理含非 ASCII 数据时，一律用文件重定向（`< file` / `--result-file` / `-o file`），禁止用 PowerShell 管道 `|` 直接喂给原生客户端；处理后抽查中文字段。

---

## 2. git submodule / worktree 分支不同步导致提交丢失或指针错乱

**发现时间**: 2026-09-20
**影响范围**: 主控仓库 + `frontend/`、`backend/` 子模块的并行开发
**症状**: 主仓库切到 feature 分支后，子模块仍停留在 `main`（或 detached HEAD）；子模块内的提交未推送，主仓库记录的 submodule 指针指向本地未推送的 commit，他人 clone 后 `git submodule update` 失败
**根本原因**: `git submodule` 默认 checkout 固定 commit（detached HEAD），不跟随主仓库分支切换；worktree 也不会自动为子模块创建同名分支。
**解决方案**:
- 进入子模块开发前，显式创建/切换分支：`cd frontend; git checkout main; git pull; git checkout -b feature/<name>`
- 提交顺序：**先**在子模块内 commit + push，**再**回主仓库 `git add frontend backend; git commit`（记录已推送的指针）
- 推送顺序：先推子模块，后推主仓库
**预防措施**: 遵循 `.qoder/rules/workflow-conventions.md` 的子模块 / worktree 约束；每次操作后用 `git submodule status` 确认指针前缀非 `+`/`-`（`+` 表示子模块 checkout 与主仓库记录不一致，`-` 表示未初始化）。

---

**最后更新**: 2026-09-20
**维护者**: AI Agent + 开发团队
````

- [ ] **Step 2: 验证 + 提交**

Run:
```powershell
Test-Path f:\project\dev\workspace\AnanoesisShell\.qoder\known-issues.md
git add .qoder/known-issues.md
git commit -m "docs: add known-issues.md with stack-agnostic seed entries"
```
Expected: `Test-Path` 返回 `True`；提交成功。

---

## Task 8: 治理文档与仓库配置

**Files:**
- Create: `.gitignore`
- Create: `.gitattributes`
- Create: `AGENTS.md`
- Create: `CLAUDE.md`
- Modify: `README.md`（保留产品说明首段，扩写结构 / quickstart）

- [ ] **Step 1: 写入 `.gitignore`**

````text
# ---- OS ----
.DS_Store
Thumbs.db
desktop.ini

# ---- IDE / Editor ----
.vscode/
.idea/
*.swp
*.swo
*~

# ---- Logs ----
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# ---- Dependencies（技术栈锁定前通用忽略，锁定后可精简）----
node_modules/
.pnp
.pnp.js
vendor/

# ---- Build outputs ----
dist/
build/
out/
target/
*.egg-info/
__pycache__/
*.pyc

# ---- Environment（保留 .env.example）----
.env
.env.local
.env.*.local
!.env.example

# ---- Testing / coverage ----
coverage/
.nyc_output/

# ---- Temp / cache ----
*.tmp
*.bak
.cache/

# ---- 敏感运维文件（含凭据，绝不入库）----
deploy/.env.production
deploy/tmp-*
scripts/tmp-*
````

- [ ] **Step 2: 写入 `.gitattributes`**

````text
# 默认自动规范化文本换行符
* text=auto

# Shell 脚本必须 LF（Linux 服务器执行，CRLF 会导致 `$'\r': command not found`）
*.sh text eol=lf

# Windows 脚本保留 CRLF
*.ps1 text eol=crlf
*.cmd text eol=crlf
*.bat text eol=crlf

# 明确文本类型，避免 diff 噪声
*.md text
*.yml text
*.yaml text
*.json text
*.conf text

# 二进制文件：禁止换行符转换与文本 diff
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.woff binary
*.woff2 binary
````

Expected（Step 1–2）: 仓库根目录出现 `.gitignore` 与 `.gitattributes`。

---

- [ ] **Step 3: 写入 `AGENTS.md`**

````text
# AGENTS.md — AI 代理指南

> 本文件为 AI 编码代理提供项目级别的指导和约束。**所有代理在本仓库工作前必须阅读本文件。**

## 项目概述

**AnanoesisShell** 是一个 AI 驱动的远程终端（AI-powered remote terminal）：用户无需记忆命令，由 AI 自动完成 Linux 运维操作。

本仓库当前处于**基础结构初始化阶段**，采用 **Spec-Driven Development (SDD)** 方法论，融合三大 AI 编码工程理念：

1. **Harness 工程** — 通过 Guides（前馈控制）和 Sensors（反馈控制）约束 AI 代理行为
2. **OpenSpec** — 规格驱动开发，specs 作为真相源，changes 管理变更
3. **Superpowers** — 可组合技能（vendored 到 `.qoder/skills/`）增强 AI 代理纪律性

> ⚠️ **技术栈尚未锁定**：前端 / 后端的语言与框架将在后续通过 OpenSpec 变更（`/opsx:propose`）决定并固化。在此之前，任何代理**不得**擅自引入具体业务框架或依赖。

## 仓库架构（AI Workspace）

本项目采用 **主控仓库 + 子仓库** 的多仓库架构，通过 `git submodule` 管理前后端代码（均固定 `main` 分支）：

| 仓库 | 角色 | 远程地址 |
|------|------|---------|
| 主控仓库（本仓库） | SDD 方法论、规格、约束门禁、多代理编排、文档 | https://github.com/13198582183/AnanoesisShell.git |
| `frontend/` 子仓库 | 前端代码（技术栈待定） | https://github.com/13198582183/AnanoesisShell-frontend.git |
| `backend/` 子仓库 | 后端代码（技术栈待定） | https://github.com/13198582183/AnanoesisShell-backend.git |

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
│   ├── commands/opsx/     # OpenSpec 原生斜杠命令
│   ├── skills/            # Vendored Superpowers 技能（8 个 + LICENSE）
│   ├── agents/            # 7 个栈无关角色子智能体
│   ├── rules/             # always_on 规则（工作流约定 / 编码规范）
│   └── known-issues.md    # 已知问题与 Bug 记录（开发前必读）
├── openspec/              # 规格驱动开发
│   ├── specs/             # 规格文件（真相源）
│   └── changes/           # 变更提案（含 archive/）
├── frontend/              # [子仓库] 前端（技术栈待定）
├── backend/               # [子仓库] 后端（技术栈待定）
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
   - 当前阶段**技术栈未锁定**，禁止擅自引入具体业务框架 / 依赖
   - 技术栈选型必须通过 OpenSpec 变更流程决定，并回写本文件新增的「技术栈选型约束」章节

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
| `/opsx:explore` | 探索一个主题 / 需求 |
| `/opsx:propose` | 提出变更（创建 change 提案） |
| `/opsx:apply` | 实施已批准的变更 |
| `/opsx:archive` | 归档已完成的变更并更新 specs |

> 命令集以 `openspec init` 实际生成、`.qoder/commands/opsx/` 下的文件为准。
````

- [ ] **Step 4: 写入 `CLAUDE.md`**

````text
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
````

- [ ] **Step 5: 重写 `README.md`（保留原产品说明首段，扩写结构 / quickstart）**

> 原 `README.md` 仅 2 行（标题 + 产品说明）。保留这两行原文（含弯引号 `don’t` 与长破折号 `—`），在其后追加以下内容：

````text
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
````

- [ ] **Step 6: 验证 + 提交**

Run:
```powershell
Get-ChildItem f:\project\dev\workspace\AnanoesisShell -File -Force | Where-Object { $_.Name -in @('.gitignore','.gitattributes','AGENTS.md','CLAUDE.md','README.md') } | Select-Object -ExpandProperty Name
git add .gitignore .gitattributes AGENTS.md CLAUDE.md README.md
git commit -m "docs: add governance docs (AGENTS/CLAUDE/README) and git config"
```
Expected: 列出 5 个文件；提交成功。

---

## Task 9: 初始化 / 结构校验脚本

**Files:**
- Create: `scripts/verify-structure.ps1`（结构门禁：校验必备路径 / 技能 / 子模块，缺失则 exit 1）
- Create: `scripts/init-workspace.ps1`（幂等初始化：子模块 + OpenSpec + vendored 技能，末尾自动校验）

> 两个脚本均**不使用全局 `$ErrorActionPreference='Stop'`**，改为在原生命令（git / openspec）后显式检查 `$LASTEXITCODE` —— 规避 Windows PowerShell 5.1 下原生命令 stderr 进度输出被当作终止性错误抛出的陷阱（对应 `.qoder/known-issues.md` 记录风格）。

- [ ] **Step 1: 写入 `scripts/verify-structure.ps1`**

````powershell
<#
.SYNOPSIS
    校验 AnanoesisShell AI Workspace 结构完整性（Harness 反馈控制门禁）。
.DESCRIPTION
    检查主控仓库必备目录/文件、子模块、OpenSpec、vendored 技能、Harness、治理文档
    是否齐备。任一缺失即以非零码退出，可用于提交前 / CI 门禁。
.NOTES
    用法：.\scripts\verify-structure.ps1 [-Root <仓库根目录>]
    退出码：0 = 全部通过；1 = 存在缺失项。
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$requiredPaths = @(
    '.gitmodules', '.gitignore', '.gitattributes',
    'AGENTS.md', 'CLAUDE.md', 'README.md', 'LICENSE',
    'frontend', 'backend',
    'openspec', 'openspec\specs', 'openspec\changes',
    '.qoder\commands\opsx',
    '.qoder\skills', '.qoder\skills\LICENSE', '.qoder\skills\README.md',
    '.qoder\agents',
    '.qoder\rules\workflow-conventions.md', '.qoder\rules\coding-standards.md',
    '.qoder\known-issues.md',
    '.harness\README.md',
    '.harness\guides\workflow.md', '.harness\guides\coding-standards.md',
    '.harness\sensors\quality.md', '.harness\sensors\drift-detection.md'
)

$requiredSkills = @(
    'brainstorming', 'writing-plans', 'executing-plans', 'test-driven-development',
    'systematic-debugging', 'verification-before-completion',
    'requesting-code-review', 'receiving-code-review'
)

$missing = @()

Write-Host "== 校验必备路径 ==" -ForegroundColor Cyan
foreach ($p in $requiredPaths) {
    if (Test-Path (Join-Path $Root $p)) {
        Write-Host "  [OK]   $p" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] $p" -ForegroundColor Red
        $missing += $p
    }
}

Write-Host "== 校验 vendored 技能（须含 SKILL.md）==" -ForegroundColor Cyan
foreach ($s in $requiredSkills) {
    $rel = ".qoder\skills\$s\SKILL.md"
    if (Test-Path (Join-Path $Root $rel)) {
        Write-Host "  [OK]   $s" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] $rel" -ForegroundColor Red
        $missing += $rel
    }
}

Write-Host "== 校验子模块初始化状态 ==" -ForegroundColor Cyan
Push-Location $Root
try {
    $subStatus = & git submodule status
    if ($LASTEXITCODE -ne 0 -or -not $subStatus) {
        Write-Host "  [MISS] git submodule status 失败或无子模块（exit $LASTEXITCODE）" -ForegroundColor Red
        $missing += 'submodules'
    } else {
        foreach ($line in $subStatus) {
            if ($line -match '^-') {
                Write-Host "  [MISS] 子模块未初始化: $line" -ForegroundColor Red
                $missing += 'submodule-uninit'
            } elseif ($line -match '^\+') {
                Write-Host "  [WARN] 子模块指针与记录不一致: $line" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK]   $line" -ForegroundColor Green
            }
        }
    }
} finally {
    Pop-Location
}

Write-Host ""
if ($missing.Count -gt 0) {
    Write-Host "结构校验失败：缺失 $($missing.Count) 项" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "结构校验通过：所有必备项齐备 [OK]" -ForegroundColor Green
exit 0
````

- [ ] **Step 2: 写入 `scripts/init-workspace.ps1`**

````powershell
<#
.SYNOPSIS
    幂等初始化 AnanoesisShell AI Workspace（子模块 + OpenSpec + vendored 技能）。
.DESCRIPTION
    在新克隆或结构缺失时运行，按序执行；已存在的部分自动跳过，可重复运行：
      1) 初始化并拉取 git submodule（frontend / backend）
      2) 若 openspec/ 不存在则运行 openspec init（原生 Qoder /opsx 命令）
      3) 若 .qoder/skills/<skill>/SKILL.md 缺失则从全局插件缓存复制 Superpowers 技能
      4) 最后调用 verify-structure.ps1 做结构门禁校验
.NOTES
    用法：.\scripts\init-workspace.ps1 [-Root <仓库根>] [-SuperpowersVersion <版本>]
    依赖：git；Node 22 + @fission-ai/openspec；全局 superpowers@<版本> 插件缓存。
    升级 Superpowers：改 -SuperpowersVersion 默认值并同步 .qoder/skills/README.md。
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$SuperpowersVersion = '5.1.0'
)

Push-Location $Root
try {
    Write-Host "[1/4] 初始化 git submodule ..." -ForegroundColor Cyan
    & git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule update 失败（exit $LASTEXITCODE）" }

    Write-Host "[2/4] 检查 OpenSpec ..." -ForegroundColor Cyan
    if (Test-Path (Join-Path $Root 'openspec')) {
        Write-Host "  openspec/ 已存在，跳过 init" -ForegroundColor Yellow
    } else {
        & openspec init --tools qoder --no-animation --force --no-copilot-cloud
        if ($LASTEXITCODE -ne 0) { throw "openspec init 失败（exit $LASTEXITCODE）" }
    }

    Write-Host "[3/4] 检查 vendored Superpowers 技能 ..." -ForegroundColor Cyan
    $skillsDst = Join-Path $Root '.qoder\skills'
    $skillsSrc = Join-Path $env:USERPROFILE ".qoder\plugins\cache\qoder-marketplace\superpowers\$SuperpowersVersion"
    if (-not (Test-Path $skillsSrc)) {
        throw "未找到 Superpowers 插件缓存：$skillsSrc（请确认全局已安装 superpowers@$SuperpowersVersion）"
    }
    $skills = @(
        'brainstorming', 'writing-plans', 'executing-plans', 'test-driven-development',
        'systematic-debugging', 'verification-before-completion',
        'requesting-code-review', 'receiving-code-review'
    )
    New-Item -ItemType Directory -Force -Path $skillsDst -ErrorAction Stop | Out-Null
    foreach ($s in $skills) {
        $dst = Join-Path $skillsDst $s
        if (Test-Path (Join-Path $dst 'SKILL.md')) {
            Write-Host "  跳过已存在技能：$s" -ForegroundColor Yellow
        } else {
            Copy-Item -Recurse -Force -ErrorAction Stop (Join-Path $skillsSrc "skills\$s") $dst
            Write-Host "  复制技能：$s" -ForegroundColor Green
        }
    }
    if (-not (Test-Path (Join-Path $skillsDst 'LICENSE'))) {
        Copy-Item -Force -ErrorAction Stop (Join-Path $skillsSrc 'LICENSE') (Join-Path $skillsDst 'LICENSE')
    }

    Write-Host "[4/4] 运行结构校验 ..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'verify-structure.ps1') -Root $Root
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
````

- [ ] **Step 3: 运行结构校验（此时 Task 1–8 已完成，应全绿）**

Run:
```powershell
cd f:\project\dev\workspace\AnanoesisShell
.\scripts\verify-structure.ps1
$LASTEXITCODE
```
Expected: 所有路径 / 技能 / 子模块均为 `[OK]`，末尾输出 `结构校验通过：所有必备项齐备 [OK]`，`$LASTEXITCODE` 为 `0`。若出现 `[MISS]`，回到对应 Task 补齐后重跑。

> 若脚本因执行策略被拦截（`无法加载...未数字签名`），先运行 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` 再重试。

- [ ] **Step 4: 提交**

```powershell
git add scripts/verify-structure.ps1 scripts/init-workspace.ps1
git commit -m "feat: add structure verification and idempotent init scripts"
```
Expected: 提交成功。

---

## Task 10: 最终验证与推送

**Files:** 无（仅验证与推送；不新增文件）

> ⚠️ **推送门禁**：设计规格约定 Task 1–9 **全程仅本地提交、不推送**，等用户验收本地结构后再统一 `git push`。因此 Step 4 **必须**先取得用户明确确认才可执行。

- [ ] **Step 1: 结构门禁全量校验**

Run:
```powershell
cd f:\project\dev\workspace\AnanoesisShell
.\scripts\verify-structure.ps1
$LASTEXITCODE
```
Expected: 所有项 `[OK]`，末尾 `结构校验通过：所有必备项齐备 [OK]`，`$LASTEXITCODE` 为 `0`。

- [ ] **Step 2: OpenSpec 校验**

Run:
```powershell
openspec validate --all
openspec list
```
Expected: `openspec validate --all` 无错误退出（exit 0）；`openspec list` 正常返回（空变更列表亦可）。

- [ ] **Step 3: Git 状态与提交历史复核**

Run:
```powershell
git status
git submodule status
git log --oneline -n 12
```
Expected:
- `git status`：working tree clean（无未跟踪 / 未提交变更）。
- `git submodule status`：frontend、backend 两行，前缀非 `-`（未初始化）也非 `+`（指针不一致）。
- `git log --oneline`：依次可见 Task 1–9 的提交（`chore` / `feat` / `docs` 前缀），以及此前的 `docs: add AI Workspace initialization design spec`。

- [ ] **Step 4: 推送（⚠️ 仅在用户明确确认后执行）**

> 未获用户确认前，**停在此处**，仅报告“本地结构已就绪、待验收”。获得确认（如用户回复“推送 / push / 确认”）后再执行下面命令。

Run（用户确认后）:
```powershell
# 子模块本身无新提交（仅克隆指针），只需推送主控仓库
git push -u origin main
```
Expected: 推送成功，输出含 `branch 'main' set up to track 'origin/main'`；`origin/main` 与本地同步。

> 若被沙箱拒绝（`git.exe 无法运行: 拒绝访问`），以“运行于沙箱外 / 提升权限”重试。

- [ ] **Step 5: 推送后复核**

Run:
```powershell
git status
git log --oneline -n 3
```
Expected: `git status` 显示 `Your branch is up to date with 'origin/main'`，working tree clean。

---

## 完成定义（Definition of Done）

本次初始化视为完成，当且仅当以下全部成立：

- [ ] `frontend/`、`backend/` 作为 submodule 存在且固定 `main`（`.gitmodules` 含 `branch = main`）
- [ ] `openspec/` 与 `.qoder/commands/opsx/`（6 个命令：explore/propose/apply/sync/update/archive）已生成，`openspec validate --all` 通过
- [ ] `.qoder/skills/` 含 14 个技能目录（6 个 `openspec-*` + 8 个 vendored Superpowers，各有 `SKILL.md`）+ `LICENSE` + `README.md`
- [ ] `.harness/` 含 `README.md` + 2 个 guides + 2 个 sensors
- [ ] `.qoder/rules/` 含 `workflow-conventions.md` + `coding-standards.md`（`trigger: always_on`）
- [ ] `.qoder/agents/` 含 7 个栈无关角色子智能体
- [ ] `.qoder/known-issues.md` 含记录规范模板 + 2 条栈无关种子条目
- [ ] 治理文档齐备：`.gitignore`、`.gitattributes`、`AGENTS.md`、`CLAUDE.md`、扩写后的 `README.md`（保留原产品说明首段）
- [ ] `scripts/verify-structure.ps1` 运行 `exit 0`；`scripts/init-workspace.ps1` 幂等可重跑
- [ ] Task 1–9 各自独立提交（约定式提交前缀 `feat` / `docs` / `chore`）
- [ ] **仅在用户明确确认后**执行 `git push -u origin main`
- [ ] 全程未锁定任何业务技术栈（前后端框架留待后续 OpenSpec 变更 `/opsx:propose` 决定）

---
