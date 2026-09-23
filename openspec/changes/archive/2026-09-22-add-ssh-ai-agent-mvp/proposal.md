## Why

运维人员在内网连接 Linux 服务器排障时，往往需要一边手敲命令、一边查阅资料，效率低且容易误操作；而公有云厂商提供的 AI 运维终端（如阿里云 OrcaTerm）通常与公有云绑定、且 AI 倾向于自动执行命令，缺乏人工管控，不适合"内网自托管 + 生产服务器错一条命令就可能酿成事故"的场景。

本变更引入一个**可内网自托管、AI 辅助但每一步命令均由人工审批、对文件增删改先备份可回滚**的 SSH 运维客户端最小可用版本（MVP），让运维人员在完全掌控的前提下借助 AI 提升排障效率。

## What Changes

- 新增 **SSH 连接与交互式终端**：连接单台 Linux 服务器，前端 xterm.js 经 WebSocket 与后端 sshj 分配的 PTY 双向流式交互。
- 新增 **服务器配置管理与凭据安全存储**：服务器信息的增删改查；SSH 密码/私钥与 LLM api key 经操作系统密钥库加密后存储，杜绝明文与硬编码。
- 新增 **OpenAI 兼容的模型接入抽象层**：首个 provider 为华为昇腾 MindIE；支持在设置项中配置 `model` / `base_url` / `api_key`（不硬编码），支持思考模式与非思考模式。
- 新增 **AI 智能体**：基于 Spring AI `ChatClient`，通过 `@Tool` 注解注入工具集，采用**手动工具执行模式**（关闭框架自动执行）以插入人工闸门。
- 新增 **人工审批闸门**：`run_command` 等有副作用的工具一律先经人工审批（WebSocket 弹框展示 AI 分析与待执行命令，内存挂起等待、超时兜底），并记录审计日志。
- 确立 **工具分级策略**：只读工具（`list_dir` / `read_file` / `system_info`）自动执行；副作用工具（`run_command`）走审批。
- 明确 **MVP 边界**：SFTP 文件传输、大文件分片阅读、文件增删改的备份/回滚两阶段、Ollama provider、桌面壳打包均**不在本变更范围**，拆分至后续变更。

## Capabilities

### New Capabilities

- `ssh-connection`: 连接单台 Linux 服务器、交互式终端（PTY 流式渲染）、服务器配置的增删改查与连接会话管理。
- `credential-store`: 敏感凭据（SSH 密码/私钥、LLM api key）经 OS 密钥库派生的主密钥加密存储，禁止明文落库与硬编码。
- `model-provider`: OpenAI 兼容的大模型接入抽象层，首个 provider 为昇腾 MindIE，支持 `model`/`base_url`/`api_key` 运行时配置与思考/非思考双模式。
- `ai-agent`: 基于 Spring AI `ChatClient` 的智能体，以 `@Tool` 注入工具集（只读自动、副作用审批），在手动工具执行模式下驱动多轮对话循环。
- `command-approval`: 命令执行的人工审批闸门（AI 提议 → 弹框 → 人工批准/取消 → 执行或回喂拒绝），含超时兜底与审计日志。

### Modified Capabilities

（无。`openspec/specs/` 当前为空，本变更不修改任何既有 capability 的需求。）

## Impact

- **新增后端**：Spring Boot 3.5.x + Spring AI + MyBatis-Plus + sshj；嵌入式 SQLite（WAL 模式）。
- **新增前端**：Vue3 + TypeScript + xterm.js + WebSocket 客户端。
- **新增契约工件**：`contract/openapi.yaml` + `contract/asyncapi.yaml`；前后端经 `openapi-generator` 从契约生成接口/类型，契约优先对齐（见 design D7、tasks 2.1–2.5）。
- **新增数据表**：`hosts` / `credentials` / `sessions` / `ai_conversations` / `ai_messages` / `approvals` / `settings`。
- **外部依赖**：华为昇腾 MindIE（OpenAI 兼容 HTTP 接口）；操作系统密钥库（经 java-keyring 调用 Windows DPAPI / macOS Keychain / Linux SecretService）。
- **关键前置风险**：MindIE 对 OpenAI `tools` 字段与标准 `tool_calls` 返回的支持程度尚未实测，直接决定智能体走"原生 tool calling"还是"文本协议降级"——列为 `tasks.md` 的第一个验证任务（spike）。
- **阶段定位**：本变更对应"阶段 1（以 Web 方式跑通核心）"；桌面壳打包（Electron/Tauri）为后续"阶段 2"，不在本变更范围。
