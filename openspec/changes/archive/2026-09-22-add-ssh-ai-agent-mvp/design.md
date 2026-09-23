## Context

本变更是项目首个功能变更，确立业务技术栈。动机见 `proposal.md - Why`，需求契约见 `specs/`；此处只记录影响实现方式的**当前状态与约束**：

- **起点**：`openspec/specs/` 为空，`frontend/`、`backend/` 子模块为空壳，技术栈此前刻意未锁定。
- **部署约束**：内网自托管、单机使用；api key 走设置项、不硬编码；面向生产服务器，故"每步命令人工审批、增删改先备份"是硬性安全底线。
- **团队约束**：开发者熟悉 Vue3 + TS 与 Spring Boot，但对 SSH 客户端与 AI Agent 领域是新手。
- **未验证前提**：华为昇腾 MindIE 对 OpenAI `tools` 字段的支持程度尚未实测（见 Risks）。
- **阶段划分**：本变更 = 阶段 1（以 Web 方式跑通核心）；桌面壳打包 = 阶段 2（后续变更）。

### 架构总览

```
[前端 Vue3 + TS]  xterm.js 终端 | 审批弹框 | 设置 | 服务器列表
      ^  WebSocket: 终端流 / 审批 / AI 流式
      v  REST: 配置 / 设置 / 审计查询
[后端 Spring Boot 3.5 + Spring AI]
   |-- 审批闸门 (手动工具执行: 关自动执行, 应用接管 tool_calls)
   |-- AI 智能体 ChatClient + @Tool 工具集 (只读自动 / 副作用审批)
   |-- 模型接入抽象层 --> MindIE (OpenAI 兼容) / 未来 Ollama / 思考-非思考
   |-- SSH 服务 (sshj) 双通道 --> 交互式 PTY(人) / exec(AI run_command) --> Linux
   |-- MyBatis-Plus + SQLite(WAL): hosts/credentials/sessions/ai_*/approvals/settings
   |-- 凭据: OS 密钥库(java-keyring) 存主密钥 --> SQLite 只存密文
```

## Goals / Non-Goals

**Goals（设计层面）：**
- 确立前端 / 后端 / 模型接入 / SSH / 存储的模块边界与协作方式。
- 定义"人工审批闸门 + 工具分级"的技术实现路径（Spring AI 手动工具执行模式）。
- 定义"交互式终端"与"AI 命令执行"两条独立会话通道。
- 定义凭据与数据的存储安全方案（不明文、不硬编码）。
- 为 tool calling 兼容性风险预留"原生 + 文本降级"双路径，使架构在两种结果下都成立。
- 定义前后端"契约优先"对齐机制（OpenAPI/AsyncAPI 契约 + 代码生成），支撑并行开发不漂移。

**Non-Goals（本设计明确不涉及，仅预留扩展点）：**
- SFTP 文件传输、大文件分片完整策略、文件增删改的备份/回滚两阶段（后续变更）。
- Ollama provider 的具体实现（抽象层预留接口）。
- 桌面壳（Electron/Tauri）打包与进程生命周期（阶段 2）。
- 多用户与权限体系（MVP 为单机单用户）。

## Decisions

### D1. 部署形态：桌面壳 + 内嵌后端，两阶段实施
- **选择**：阶段 1 以纯 Web 方式开发（Spring Boot 后端 + Vue3 前端，浏览器访问 `localhost`）；阶段 2 再套桌面壳并捆绑运行时。
- **理由**：形态 C 本质 = Web 架构 + "单机打包壳"。先跑 Web 可用最低门槛验证价值最高、风险最大的部分（AI + 审批），把 JRE 捆绑、进程编排、打包等与核心无关的复杂度推迟；阶段 1 成果 100% 复用到阶段 2。
- **替代**：直接做 Electron（须放弃 Spring Boot，与团队技能冲突）；纯 Web 多用户服务（不符单机自托管诉求）。

### D2. AI 框架：Spring AI
- **选择**：Spring AI 的 `ChatClient` + `@Tool` + OpenAI 兼容 starter。
- **理由**：与 Spring Boot 3.5 无缝；自带多 provider 抽象、tool calling、流式，正好覆盖"多模型 + 工具 + 思考模式"需求，减少自研。
- **替代**：LangChain4j（成熟但非 Spring 原生，集成需适配）；自封装 HTTP 客户端（SSE、tool 协议、重试全自研，工作量大，不适合新手首版）。

### D3. 人工审批闸门：手动工具执行 + 工具分级
- **选择**：关闭 Spring AI 的内部自动工具执行（`internalToolExecutionEnabled=false`），由应用接管 `tool_calls`；工具分两级——只读工具（`list_dir`/`read_file`/`system_info`）自动执行，副作用工具（`run_command`）先经审批。审批流程：生成 `approval_id` → WebSocket 推弹框 → 挂起等待 → 执行或回喂"用户已拒绝"。
- **理由**：`@Tool` 默认自动执行会违背"每步命令人工审批"的安全底线；手动模式让应用掌控执行时机。用"工具设计"而非"命令文本"划分安全边界，既守住底线又避免审批疲劳。
- **替代**：在 `@Tool` 方法内部阻塞等待审批（在异步 HTTP/WS 模型下挂起别扭、长期占用连接，否决）；所有工具一律审批（诊断时审批疲劳）；`run_command` 内做命令白名单分级（管道/重定向/组合命令难以静态判全，脆弱且有绕过风险，否决）。

### D4. SSH：sshj + 双会话通道 + 输出约束
- **选择**：SSH/SFTP 库用 sshj。会话分两条独立通道——通道 1 交互式 PTY shell（人用，WebSocket ↔ xterm.js 双向流式）；通道 2 exec channel（AI 的 `run_command`，取 stdout/stderr/exit code）。`run_command` 施加执行超时、输出长度上限、非交互模式。
- **理由**：sshj API 现代易用、支持 PTY/SFTP/密钥认证，新手上手快。两通道分离避免 AI 命令干扰用户正在使用的终端；输出约束防止 `tail -f` 挂死、超大输出撑爆上下文、`sudo`/`vim` 交互卡死。
- **替代**：Apache MINA SSHD（功能最全、最活跃，但 API 底层、曲线陡）；JSch mwiede fork（资料多但 API 旧式）。

### D5. 模型接入抽象：多 Provider + 思考模式 + 动态构造
- **选择**：定义统一 `ChatClient` 抽象，Provider 适配层对接 MindIE（OpenAI 兼容），未来扩展 Ollama。思考模式读取并区分 `reasoning_content` 与 `content`，非思考仅取 `content`；默认模式可配。**手动构造** `ChatModel`（运行时用设置项的 base_url/api_key/model 组装），不依赖 Spring AI auto-config 的单例 bean。
- **理由**：满足"可配多厂家 + 思考/非思考"；auto-config 默认只产单个 bean，无法支持设置界面运行时切换 provider，故须手动构造。思考过程的 `reasoning_content` 正好填充审批弹框的"AI 分析"，与人工审核天然契合。
- **替代**：直接用 auto-config 单例（无法运行时切换，否决）。

### D6. 数据与凭据：SQLite(WAL) + MyBatis-Plus + OS 密钥库
- **选择**：持久化用嵌入式 SQLite（置于用户数据目录，WAL 模式）+ MyBatis-Plus（sqlite-jdbc 驱动）。敏感凭据（SSH 密码/私钥、api key）经 java-keyring 调用 OS 密钥库（DPAPI/Keychain/SecretService）托管的主密钥加密后，仅以密文存 SQLite；密钥库不可用时明确报错，不静默降级为明文。
- **理由**：桌面单机无需独立数据库服务，SQLite 免安装、够用；WAL 缓解并发；MyBatis-Plus 为团队所熟。凭据受 OS 级保护、绑定系统用户，满足"不明文、不硬编码"。
- **替代**：MySQL（多用户 Web 才需要，单机过重）；用户主密码派生密钥（每次启动需输入，作为密钥库不可用时的回退，见 Risks）；明文/配置文件存储（违背安全要求，否决）。

### D7. 通信与接口契约：契约优先（OpenAPI/AsyncAPI）+ REST + WebSocket + 内存挂起
- **选择**：**前后端契约优先对齐**——REST 接口以 OpenAPI 3.x 定义于 `contract/openapi.yaml`（`/api/hosts`、`/api/sessions`、`/api/model-configs`(+`/active`)、`/api/settings`、`/api/approvals`、`/api/conversations`）；WebSocket 消息以 AsyncAPI 定义于 `contract/asyncapi.yaml`。契约冻结后经 `openapi-generator` 生成后端 Spring controller 接口/DTO 与前端 TypeScript 客户端/类型，作为前后端唯一真相源。REST 承载 CRUD（服务器配置、设置、审计查询）；WebSocket 承载终端流、审批请求/响应、AI 流式增量；审批等待用内存挂起（`CompletableFuture` + 超时兜底），超时按"取消"处理。消息类型约定：`approval_request`/`approval_response`/`terminal_output`/`terminal_input`/`ai_stream`。
- **理由**：终端流式、审批异步、AI 流式都需全双工推送；单机单用户下内存挂起最简单直接，审计日志已独立持久化，重启丢失挂起态可接受。**契约优先 + 代码生成**让分属独立子模块、由不同智能体并行实现的前后端天然对齐接口，显著降低联调返工。
- **替代**：前后端各自手写接口/类型（易漂移、联调返工，否决）；审批状态持久化 + 重启恢复（更可扩展但复杂，留待后续需要时）。

## Risks / Trade-offs

- **[MindIE tool calling 兼容性未知]** 是否支持 `tools` 字段、是否返回标准 `tool_calls`、思考模式下是否正常，均未实测 → **Mitigation**：`tasks.md` 第一个任务即做探针 spike 验证；同步准备"文本协议（ReAct）降级"预案（系统提示描述工具 + 解析模型输出的约定 JSON），使 D3 的审批闸门在两种结果下都成立。
- **[OS 密钥库在 Linux 无桌面环境不可用]** SecretService 可能缺失 → **Mitigation**：提供"用户主密码派生密钥"回退路径；密钥库不可用时明确报错，绝不静默明文存储。
- **[内存挂起的审批在后端重启后丢失]** → **Mitigation**：阶段 1 接受（单机场景）；审计日志已持久化；后续可升级为状态持久化恢复。
- **[大文件 / 超长命令输出撑爆 AI 上下文]** → **Mitigation**：`read_file` 带行数上限、`run_command` 输出截断；后续变更引入 grep 定位 + 摘要滑窗。
- **[交互式命令（sudo/vim）在 AI 通道卡死]** → **Mitigation**：AI exec 通道强制非交互 + 超时；需交互的操作引导用户走人工终端通道。
- **[Trade-off] 形态 C 比纯 Web 重**（多出壳 + 进程编排 + JRE 捆绑）→ 以两阶段推迟该复杂度，先交付核心价值。
- **[Trade-off] sshj 生态资料少于 JSch** → 换取现代易用的 API 与更快的首版开发速度。

## Migration Plan

- 本变更为全新能力，无既有系统数据迁移。
- **部署（阶段 1）**：后端产出 Spring Boot 可执行 jar，前端产出静态资源；本地/内网单机启动后浏览器访问 `localhost`。
- **数据初始化**：SQLite 文件置于用户数据目录，首次启动经迁移脚本建表（迁移工具在 tasks 中确定，倾向 Flyway）。
- **回滚**：作为首个功能变更，回滚即移除该模块；表结构变更以版本化迁移脚本管理，保证可前滚/回退。
- **阶段 2（后续变更）**：为同一后端套桌面壳，前后端产物直接复用，不改核心逻辑。

## Open Questions

以下为可安全延后、不改变 specs / 架构方法 / 任务拆分的未知项：

- 桌面壳最终选 Electron 还是 Tauri（阶段 2 决定，不影响阶段 1）。
- 数据库迁移工具选 Flyway 还是 Liquibase（实施细节）。
- 前端 UI 组件库选型（不影响架构边界）。
- 会话录制/回放是否纳入（增强项，后续变更评估）。
