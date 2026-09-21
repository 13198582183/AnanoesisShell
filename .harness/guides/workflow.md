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
