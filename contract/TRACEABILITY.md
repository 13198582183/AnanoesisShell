# 接口契约追溯表（Contract ↔ Spec Traceability）

> 变更：`add-multi-session-agent-terminal` ｜ 对应 `tasks.md` 2.1 / 2.2 / 2.3 / 2.4 / 2.5 / 2.6 / 14.7
> 契约文件：`contract/openapi.yaml`（REST，OpenAPI 3.0.3）、`contract/asyncapi.yaml`（WebSocket，AsyncAPI 2.6.0）
> 真相源：`openspec/changes/add-multi-session-agent-terminal/specs/*`（8 个 spec）+ `design.md`（D2/D3/D5/D7/D8/D9/D10）
>
> V2 契约在 V1（5 个 spec）基础上新增 3 个 spec（terminal-workspace、conversation-management、sftp-transfer）
> 并更新其余 spec。本表将八个 capability 的每条 Requirement/Scenario 映射到端点/消息和测试文件。

---

## 1. REST 端点 ↔ spec 追溯

### 1.1 V1 既有端点（保留不变）

| # | 端点 / operationId | 来源 spec | Requirement | Scenario | 关键契约要素 |
|---|---|---|---|---|---|
| R1 | `GET /api/hosts` · listHosts | ssh-connection | 服务器配置管理 | 新增服务器配置（列表展示） | `Host[]`；writeOnly 凭据剔除，`credential_set` 掩码 |
| R2 | `POST /api/hosts` · createHost | ssh-connection + credential-store | 服务器配置管理 / 凭据加密存储 | 新增服务器配置 | writeOnly 凭据；503 `credential_protection_unavailable` |
| R3 | `GET /api/hosts/{id}` · getHost | ssh-connection | 服务器配置管理 | —（查看） | 单个 `Host`；不含明文 |
| R4 | `PUT /api/hosts/{id}` · updateHost | ssh-connection + credential-store | 服务器配置管理 | 编辑既有配置 | 凭据可选；503 |
| R5 | `DELETE /api/hosts/{id}` · deleteHost | ssh-connection | 服务器配置管理 | 删除配置 | 204 |
| R6 | `GET /api/sessions` · listSessions | ssh-connection | 连接会话生命周期 | 主动断开、远端关闭 | `Session.status`/`end_reason` |
| R7 | `GET /api/model-configs` · listModelConfigs | model-provider | 模型配置管理 | — | `ModelConfig[]`；`is_active`；`api_key_set` 掩码 |
| R8 | `POST /api/model-configs` · createModelConfig | model-provider | 模型配置管理 | 新增并切换 | 密文存储；503 |
| R9 | `GET /api/model-configs/{id}` · getModelConfig | model-provider | 模型配置管理 | —（查看） | `api_key` 不回显 |
| R10 | `PUT /api/model-configs/{id}` · updateModelConfig | model-provider | 模型配置管理 | 编辑 | `api_key` 可选；503 |
| R11 | `DELETE /api/model-configs/{id}` · deleteModelConfig | model-provider | 模型配置管理 | —（删除） | 204；删除生效配置→409 |
| R12 | `PUT /api/model-configs/active` · setActiveModelConfig | model-provider | 模型配置管理 | 新增并切换（设为生效） | `ActiveModelConfigRequest{id}` |
| R13 | `GET /api/settings` · getSettings | model-provider | 思考与非思考双模式 | — | `Settings.default_thinking_mode` |
| R14 | `PUT /api/settings` · updateSettings | model-provider | 思考与非思考双模式 | 选择默认模式 | 更新默认模式 |
| R15 | `GET /api/approvals` · listApprovals | command-approval | 审批审计日志 | 记录一次审批 | 分页 `ApprovalsPage`；`decision`/`execution.status` |
| R16 | `GET /api/conversations` · listConversations | ai-agent | 自然语言意图理解与多轮对话 | 多轮上下文延续 | `Conversation[]`（应用级管理接口） |
| R17 | `POST /api/conversations` · createConversation | ai-agent | 自然语言意图理解与多轮对话 | 用户提出运维请求 | `ConversationCreate{host_id?,title?}`（应用级） |

### 1.2 V2 新增端点

| # | 端点 / operationId | 来源 spec | Requirement | Scenario | 关键契约要素 |
|---|---|---|---|---|---|
| R18 | `POST /api/sessions` · createSession | terminal-workspace | 每次连接创建独立工作区 | 重复连接同一服务器 | `CreateSessionRequest{host_id}`→`SessionCreated{id,host_id,status,control_token}`；control_token 仅一次展示 |
| R19 | `POST /api/sessions/{id}/close` · closeSession | terminal-workspace + ssh-connection | 停止接管与关闭 / 连接会话生命周期 | 关闭忙碌连接 | X-Session-Control；204/403/404 |
| R20 | `POST /api/sessions/{id}/conversations` · createSessionConversation | ai-agent + terminal-workspace | 自然语言意图理解与多轮对话 / 连接级执行互斥 | 用户提出运维请求 | X-Session-Control；返回含 `session_id` 的 `Conversation` |
| R21 | `PUT /api/sessions/{id}/active-conversation` · setActiveConversation | conversation-management | 历史与连接执行权分离 | 快速切换历史 | X-Session-Control；`ActiveConversationRequest{conversation_id}` |
| R22 | `GET /api/sessions/{id}/conversations` · listSessionConversations | conversation-management | 有界会话与消息查询 | 历史逐渐增长 | keyset 游标 (created_at,id)；默认 30/最大 100；`ConversationListResponse` |
| R23 | `GET /api/conversations/{id}/messages` · listConversationMessages | conversation-management + ai-agent | 有界会话与消息查询 / 操作透明性 | 历史逐渐增长 | keyset 游标 (seq,id)；默认 50/最大 200；`MessageListResponse`；消息含 source/command_id/run_id |
| R24 | `DELETE /api/conversations/{id}` · deleteConversation | conversation-management | 单条与批量手动删除 | 删除非活动对话 / 删除活动对话 | 204/409（活动对话冲突） |
| R25 | `POST /api/conversations/batch-delete` · batchDeleteConversations | conversation-management | 单条与批量手动删除 | 删除活动对话 | `BatchDeleteRequest{ids}`（最多 100）；全成功或全不删；409 |
| R26 | `GET /api/sessions/{id}/files` · listSessionFiles | sftp-transfer | 连接内远端文件浏览 | 同主机两个连接浏览不同目录 / 超大目录 | X-Session-Control；path/cursor/limit；`DirectoryListResponse{FileEntry[]}` |
| R27 | `POST /api/sessions/{id}/transfers` · createTransfer | sftp-transfer | 本地文件上传到远端 / 远端文件下载到本地 | 上传单个文件 / 同名文件需要覆盖 | X-Session-Control；`CreateTransferRequest`；409/429 |
| R28 | `PUT /api/transfers/{id}/content` · uploadTransferContent | sftp-transfer | 本地文件上传到远端 | 上传单个或多个文件 | `application/octet-stream`；x-skip-codegen: true；409/413 |
| R29 | `GET /api/transfers/{id}/content` · downloadTransferContent | sftp-transfer | 远端文件下载到本地 | 下载二进制及中文文件 | ticket 参数；Content-Disposition/Cache-Control/Referrer-Policy；x-skip-codegen: true |
| R30 | `POST /api/transfers/{id}/download-ticket` · claimDownloadTicket | sftp-transfer | 远端文件下载到本地 | 下载票据过期或并发使用 | X-Session-Control；`DownloadTicket{ticket}`；409 |
| R31 | `GET /api/transfers/{id}` · getTransfer | sftp-transfer | 传输进度取消与资源隔离 | 大文件与取消 | `Transfer` 对象（方向/字节/状态/失败码） |
| R32 | `POST /api/transfers/{id}/cancel` · cancelTransfer | sftp-transfer | 传输进度取消与资源隔离 | 大文件与取消 / 关闭连接与断线 | 幂等取消；`Transfer` 响应 |

### 1.3 V2 模型配置扩展字段

| 字段 | 来源 spec | Requirement | Scenario | 契约要素 |
|---|---|---|---|---|
| `context_window_tokens` | model-provider + agent-context | 模型容量与输出预留配置 / 请求总 token 预算 | 配置不合理的预算 / 未知模型使用缺省容量 | integer, 默认 8192, 范围 1024..2097152 |
| `max_output_tokens` | model-provider + agent-context | 模型容量与输出预留配置 / 请求总 token 预算 | 配置不合理的预算 | integer, 默认 1024 |
| `output_limit_field` | model-provider | 显式协议扩展 | 通用端点拒绝未知字段 | enum [max_tokens, max_completion_tokens], 默认 max_tokens |
| `thinking_request_format` | model-provider | 显式协议扩展 | 通用端点拒绝未知字段 | enum [none, qwen_compatible], 默认 none |

### 1.4 REST 统一错误码 ↔ 失败 Scenario

| ErrorCode | HTTP | 来源 spec | Requirement / Scenario | 承载位置 |
|---|---|---|---|---|
| `validation_error` | 400 | 通用 | 请求校验 | REST |
| `not_found` | 404 | 通用 | 资源不存在 | REST |
| `conflict` | 409 | model-provider / conversation-management | 删除生效配置冲突 / 删除活动对话 | REST |
| `credential_protection_unavailable` | 503 | credential-store | 密钥库不可用 | REST |
| `host_unreachable` | —（WS） | ssh-connection | 建立 SSH 连接 / 主机不可达 | WS `terminal_output`(type=error) |
| `auth_failed` | —（WS） | ssh-connection | 建立 SSH 连接 / 认证失败 | WS `terminal_output`(type=error) |
| `model_endpoint_unreachable` | —（WS） | model-provider | 端点不可达 | WS `ai_stream`(type=error) |
| `model_endpoint_error` | —（WS） | model-provider | 端点返回错误 | WS `ai_stream`(type=error) |
| `api_key_missing` | —（WS） | credential-store | 未配置 api key | WS `ai_stream`(type=error) |
| `internal_error` | 500 | 通用 | 服务器内部错误 | REST/WS |
| `session_control_required` | 401 | terminal-workspace | 连接级授权与事件归属 / 同主机不同连接请求混用 | REST（缺少 X-Session-Control） |
| `session_control_invalid` | 403 | terminal-workspace | 连接级授权与事件归属 / 同主机不同连接请求混用 | REST（凭证错误/过期） |
| `transfer_quota_exceeded` | 429 | sftp-transfer | 传输进度取消与资源隔离 / 排队和就绪领取 | REST（队列已满） |
| `transfer_conflict` | 409 | sftp-transfer | 同名文件需要覆盖 / 下载票据过期或并发使用 | REST（目标存在/状态冲突） |
| `transfer_target_changed` | 409 | sftp-transfer | 同名文件需要覆盖（发布前复核变化） | REST |
| `context_budget_exceeded` | —（WS） | agent-context | 请求总 token 预算 / 最小请求也无法容纳 | WS `ai_stream`(type=error) |

---

## 2. WebSocket 消息 ↔ spec 追溯

| # | Channel | 消息 (name) | 方向 | 来源 spec | Requirement | Scenario | 关键契约要素 |
|---|---|---|---|---|---|---|---|
| W1 | `/terminal` | `terminal_input` | 发送 | ssh-connection + terminal-workspace | 交互式终端会话 / 连接级授权 / 远端终端尺寸同步 | 命令实时回显 / 调整窗口或切回终端 | `action`(open/input/close/**bind**/**resize**)；bind 携带 `session_id`+`control_token`；resize 携带 `cols`+`rows` |
| W2 | `/terminal` | `terminal_output` | 接收 | ssh-connection + terminal-workspace | 建立 SSH 连接 / 交互式终端 / 连接会话生命周期 / 连接级授权 | 认证失败/主机不可达/远端关闭 / 断线后重新订阅 | `type`(data/error/closed/**bound**/**subscription_snapshot**)；所有事件携带 `session_id`+`event_seq`；快照含屏幕缓存与事件尾部 |
| W3 | `/approval` | `approval_request` | 接收 | command-approval + ai-agent | 执行前人工审批 / 审批状态重连与竞态裁决 | 用户批准执行 / 断线后重新订阅 | `approval_id`；`version`（V2）；`command`；`session_id`+`event_seq` |
| W4 | `/approval` | `approval_response` | 发送 | command-approval | 执行前人工审批 | 用户批准执行 / 修改命令再确认 | `decision`(approve/cancel/**modify**)；`modified_command`+`expected_version`（V2） |
| W5 | `/ai` | `ai_stream` | 发送/接收 | model-provider + ai-agent + agent-context + credential-store | 流式响应 / 操作透明性 / 请求总 token 预算 / 上下文超限单次恢复 / 受控停止任务 | 流式增量 / 展示工具调用 / 上下文裁剪 / 恢复重置 / Agent 生成中 Ctrl+C 即时打断 | `type`( …/**context_notice**/**attempt_reset**/**stop_turn**)；`session_id`+`event_seq`；`context_notice` 含候选/保留/估算；`attempt_id`+`attempt_number`；`stop_turn` 为上行帧（携 `conversation_id`，命中在飞回合时后端以 `finish_reason=stopped` 的 final 收尾，未命中静默） |

### 2.1 WS 消息覆盖的关键 Scenario 细节

| Scenario（来源） | 承载消息 / 字段 |
|---|---|
| 命令实时回显（ssh-connection） | `terminal_output` type=data，stream=stdout/stderr |
| 交互式程序可用（ssh-connection） | `terminal_input` action=input + `terminal_output` type=data |
| 中断运行中的命令（ssh-connection） | `terminal_input.data` 含 `\u0003` |
| Agent 生成中 Ctrl+C 即时打断（ai-agent V2） | `ai_stream` type=stop_turn（上行，conversation_id）→ `final` finish_reason=stopped + 停止注记 answer_delta |
| 认证失败 / 主机不可达（ssh-connection） | `terminal_output` type=error，error_code |
| 远端关闭 / 主动断开 / 超时（ssh-connection） | `terminal_output` type=closed，end_reason |
| 调整窗口或切回终端（ssh-connection V2） | `terminal_input` action=resize，cols/rows |
| 绑定连接与验证控制权（terminal-workspace V2） | `terminal_input` action=bind，session_id+control_token → `terminal_output` type=bound |
| 断线后重新订阅（terminal-workspace V2） | `terminal_output` type=subscription_snapshot，含 snapshot |
| 同主机不同连接请求混用（terminal-workspace V2） | 服务端校验 session_id 归属，拒绝不匹配 |
| 用户批准执行（command-approval） | `approval_request` → `approval_response`(approve) |
| 修改命令再确认（command-approval V2） | `approval_response`(modify, modified_command, expected_version) |
| 断线后重新订阅审批（command-approval V2） | 审批快照恢复，按标识去重 |
| 批准与停止同时发生（command-approval V2） | 服务端只接受一个合法状态转换 |
| 思考/非思考模式（model-provider） | `ai_stream` type=thinking_delta/answer_delta |
| 流式输出增量（model-provider） | `ai_stream` type=answer_delta |
| 展示工具调用（ai-agent） | `ai_stream` tool_call/tool_result |
| 两个连接分别执行任务（ai-agent V2） | session_id 隔离，不同连接独立处理 |
| 生成中停止（ai-agent V2） | 停止后模型的流终止、未执行工具失效 |
| 历史超过六十条（agent-context V2） | 60 条窗口 + keyset 分页 |
| 少于六十条仍超限（agent-context V2） | `ai_stream` type=context_notice |
| 工具执行后模型拒绝上下文（agent-context V2） | `ai_stream` type=attempt_reset |
| 恢复仍然失败（agent-context V2） | 第二次失败终止当前 run |
| 未配置 api key（credential-store） | `ai_stream` type=error，error_code=api_key_missing |

---

## 3. 安全约束落实（credential-store 横切）

| spec 要求 | 契约落实 |
|---|---|
| 凭据不明文落库 / 按需解密使用 | `Host.password`/`private_key`/`passphrase` 与 `ModelConfig.api_key` 全部 `writeOnly:true` |
| 需知"是否已配置"而不泄露 | 响应仅返回掩码布尔：`Host.credential_set`、`ModelConfig.api_key_set` |
| API Key 不硬编码 | `api_key` 仅经用户请求写入，无默认值 |
| 密钥库不可用明确报错 | 保存凭据类端点声明 `503 credential_protection_unavailable` |
| 明文凭据不写入日志/审计/错误信息 | `Approval`/`ToolCallEvent` 仅记录工具入参；`Error.message` 不含内部细节 |
| 控制 token 不持久化（V2） | `SessionCreated.control_token` 仅一次展示；WS bind 提交后服务端只存散列 |
| 下载票据安全（V2） | 单次有效、30 秒过期；响应 no-store/Referrer-Policy:no-referrer |

---

## 4. 测试文件映射

### 4.1 REST 端点测试

| 端点组 | 后端测试文件 | 前端测试文件 |
|---|---|---|
| hosts (R1-R5) | `HostsApiIntegrationTest.java`、`HostsApiCredentialLoggingTest.java` | `hosts.api.spec.ts` |
| sessions (R6, R18-R19) | `SessionsApiIntegrationTest.java` | `sessions.api.spec.ts` |
| sessions-control (R20-R22) | `SessionControlControllerTest.java` | `sessions-control.api.spec.ts` |
| model-configs (R7-R12, 1.3) | `ModelConfigsApiIntegrationTest.java`、`ModelConfigsApiCredentialLoggingTest.java`、`ModelConfigMigrationTest.java`（tasks 8.2 迁移）、`OpenAiCompatibleChatModelProviderTest.java`（装配 tasks 7.2/8.1） | `model-configs.api.spec.ts` |
| settings (R13-R14) | `SettingsApiIntegrationTest.java` | `settings.api.spec.ts` |
| approvals (R15) | `ApprovalsApiIntegrationTest.java`、`ApprovalGateIntegrationTest.java` | `approvals.api.spec.ts` |
| conversations (R16-R17, R23-R25) | `ConversationsApiIntegrationTest.java` | `conversations.api.spec.ts` |
| files (R26) | `FileControllerTest.java` | `files.api.spec.ts` |
| transfers (R27, R30-R32) | `TransferControllerTest.java` | `transfers.api.spec.ts` |
| TransferContent (R28-R29) | `TransferContentContractTest.java`（手写；tasks 2.5/14.7）、`TransferContentTest.java`（HTTP 行为）、`TransferContentTicketLoggingTest.java`（14.7 票据日志安全） | `transfer-content.ts`（手写）、`transfer-content.spec.ts`（含 14.7 票据持久化安全） |

### 4.2 WebSocket 消息测试

| 消息 | 后端测试文件 | 前端测试文件 |
|---|---|---|
| terminal_input/output (W1-W2) | `TerminalWebSocketHandlerTest.java` | `ws-messages.spec.ts`（V2 更新） |
| approval_request/response (W3-W4) | `ApprovalWebSocketHandlerTest.java` | `ws-messages.spec.ts`（V2 更新） |
| ai_stream (W5) | `AiWebSocketHandlerTest.java` | `ws-messages.spec.ts`（V2 更新） |

### 4.3 二进制流式适配例外（design D10）

`PUT /api/transfers/{id}/content` 与 `GET /api/transfers/{id}/content` 标记 `x-skip-codegen: true`，
意图从 OpenAPI 生成的 controller/DTO/客户端集合排除，由 `TransferContentController.java` 手写流式适配：
- PUT 从 servlet 输入流读取，64 KiB 缓冲转 SFTP
- GET 经 `StreamingResponseBody` 流式写响应，避免整文件加载到内存
- 不使用默认 Resource 消息转换器整包缓冲
- 契约测试逐项核对路径、媒体类型、鉴权、状态码与响应头

> **tasks 2.4 验证结论**：openapi-generator 7.14.0 不原生支持 `x-skip-codegen` 自定义扩展，
> 生成物中仍包含 `TransferContentApi.java`（后端）与 `TransferContentApi.ts`（前端）。
> 但两者均为**死代码**：后端 `TransferContentController` 不实现生成接口，
> 前端 `transfer-content.ts` 使用 XHR 手写版本而非生成客户端。
> 生成文件不影响运行时行为，手写实现完全独立。

### 4.4 安全测试映射（task 14.7）

| 安全要求 | 后端测试 | 前端测试 |
|---|---|---|
| 14.7.1 ticket 不进日志 | `TransferContentTicketLoggingTest.java`（DEBUG 级别全量日志捕获断言） | — |
| 14.7.2 control_token 不进前端持久存储 | — | `workspaces.spec.ts`（localStorage/sessionStorage/$state 序列化三重验证） |
| 14.7.3 票据 GET 不接受通用执行操作 | `TransferContentContractTest.java`（OpenAPI 端点方法/参数校验） | — |
| 14.7.4 本地绝对路径不被后端用于磁盘读写 | `TransferContentContractTest.java`（SftpService.validatePath 拒绝 Windows/相对/穿越路径） | — |
| 14.7.5 上传下载内容不流入模型和审计正文 | `TransferContentContractTest.java`（契约层验证端点无 JSON 请求/响应体）+ `TransferContentTicketLoggingTest.java`（上传内容不进日志） | `transfer-content.spec.ts`（ticket 不进 localStorage/sessionStorage） |

---

## 5. 开放问题（V2 新增）

> V1 的 Q1-Q8 已在冻结时裁定。V2 新增待澄清点：

- **Q9｜控制 token 长度与刷新策略**：design D2 规定 256-bit，但 token 刷新（如重绑定）流程 spec 未详细规定。契约当前不支持 token 刷新，需确认。
- **Q10｜订阅快照缓冲上限**：design D2 默认 1 MiB 事件缓冲，但具体裁剪策略（按时间/大小/事件数）spec 未逐字规定。契约以 `has_gap` 标识缺口，需确认。
- **Q11｜审批修改的到期时间保留**：design D5 规定修改保留原到期时间，但"原到期时间"是从首次创建算起还是从最近修改算起？契约按首次创建处理，需确认。

---

## 6. 契约冻结记录（V2）

| 项 | 内容 |
|---|---|
| 契约版本 | openapi `0.2.0-frozen` / asyncapi `0.2.0-frozen` |
| 冻结状态 | ⏳ 待冻结 |
| 评审人（backend） | backend-engineer |
| 评审人（frontend） | frontend-engineer |
| 冻结日期 | — |
| 变更策略 | V2 冻结后任何字段/枚举/错误码调整须走「契约修订」流程并更新本追溯表 |
| 校验命令 | OpenAPI：`npx @redocly/cli lint contract/openapi.yaml`；AsyncAPI：`npx @asyncapi/cli validate contract/asyncapi.yaml` |
| 二进制例外 | `TransferContent` tag 端点（R28/R29）标记 `x-skip-codegen: true`。生成器不原生支持此扩展，生成物为死代码（后端不实现、前端不使用），手写流式适配（design D10） |
