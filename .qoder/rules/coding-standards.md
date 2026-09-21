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
