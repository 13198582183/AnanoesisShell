---
trigger: always_on
alwaysApply: true
---

# Coding Standards — 编码规范（核心约束）

> 通用注释规范见 `.harness/guides/coding-standards.md`。本目录规则依据 `add-ssh-ai-agent-mvp` 的设计、契约与实际代码提取；不是所有存量代码已达标的证明。新增和修改代码必须遵守，存量缺口通过后续 OpenSpec 变更整改，不能通过改写规格掩盖。

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

## 技术栈与职责边界
- 前端：Vue3 + TypeScript + Vite + Pinia + Vue Router + xterm.js；当前使用原生 CSS，没有引入组件库或 Tailwind。
- 后端：Java 17 编译基线、Spring Boot 3.5、Spring AI 1.1、MyBatis-Plus、SQLite、Flyway、sshj、java-keyring。具体版本以 `backend/pom.xml`、前端清单与锁文件为准；开发机 JDK 21 不等于 Java 21 源码基线。
- 保持主控仓库（规格/契约/门禁）与前后端子仓库边界；新增框架、桌面运行时、迁移存储必须先通过 OpenSpec 决策。

## 契约优先与安全边界
- 行为以 `openspec/specs/` 为准，未归档需求对照活动变更；REST 和 WS 线协议分别以 `contract/openapi.yaml`、`contract/asyncapi.yaml` 为准，追溯关系维护在 `contract/TRACEABILITY.md`。
- 新增字段、枚举、错误码、WS 动作时先修订契约，再生成/对齐类型、实现和测试；禁止临时发明另一套前后端协议。
- REST 后端接口/DTO、前端客户端是生成物，禁止直接手改；WS 当前是手写 DTO/类型与契约测试，不得声称已实现 AsyncAPI 自动代码生成。
- 区分 HTTP 成功、WS 已连接、SSH 已就绪、审批已批准、命令已成功；任何一层的成功不得替代其他层的状态。
- 真实密码、私钥、passphrase、API Key 不得进入源码、示例、日志、截图、审计或错误详情；生成 DTO 的 `writeOnly` 不保证 `toString()` 安全，不记录整个请求对象。
- UI 展示的模型回复和远端输出视为不可信数据；AI 副作用工具始终走后端审批。人工 Shell 与 AI exec 分离，不把 AI 命令偷偷写入用户 PTY。
- 不新增吞异常路径；资源清理失败可在保留原始故障的前提下受控记录，不能伪装业务成功。

## 专项规则入口
- 修改前端时阅读 `frontend-ui.md`：样式、组件、交互、终端与测试。
- 修改后端时阅读 `backend-standards.md`：分层、SSH/AI、审批与安全。
- 修改实体、SQL、设置或持久化时阅读 `database-standards.md`。
- 选择依赖、打包或兼容测试时阅读 `platform-compatibility.md`：仅 Linux 远端、Windows 7/10/11 客户端目标。
