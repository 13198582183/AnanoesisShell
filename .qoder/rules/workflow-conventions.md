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
