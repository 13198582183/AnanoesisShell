## 1. 前置验证：MindIE tool calling 兼容性 spike

- [ ] 1.1 编写独立探针程序，用设置中的 base_url/api_key/model 向 MindIE 的 OpenAI 兼容端点发送带 `tools` 字段的对话请求，验证是否返回标准 `tool_calls` 结构；将原始响应与结论（支持/不支持/部分支持）记录到变更目录下的 spike 笔记。验证：探针运行输出被保存，结论明确可查
- [ ] 1.2 扩展探针，在思考模式下重复 1.1，验证 `reasoning_content`（思考过程）与 `tool_calls` 能否共存、字段是否完整。验证：探针输出显示思考模式下 tool calling 的实际行为并被记录
- [ ] 1.3 若 1.1 或 1.2 表明原生 tool calling 不可用，则验证文本协议（ReAct）降级路径：用系统提示描述工具、令模型输出约定 JSON、探针解析该 JSON；否则标记为“不适用”。验证：降级路径探针能稳定解析出工具名与参数，或明确记录不适用
- [ ] 1.4 依据 1.1–1.3 结果确定智能体实现路径（原生 `tool_calls` / 文本协议降级），写入变更目录的决策记录（供 design.md D3/D5 与第 9 组实现引用）。验证：决策记录文件存在且明确选定一条路径

## 2. 接口契约、脚手架与代码生成（契约优先）

- [x] 2.1 由 architect 依据 5 个 spec + design D7 产出 REST 契约 `contract/openapi.yaml`（OpenAPI 3.x），覆盖 `/api/hosts`、`/api/sessions`、`/api/model-configs`(+`/active`)、`/api/settings`、`/api/approvals`、`/api/conversations`(+`/{id}/messages`) 端点，字段/枚举/错误码与各 spec 的 Scenario 对齐。验证：OpenAPI 语法校验通过，附端点↔spec 追溯表
- [x] 2.2 由 architect 产出 WebSocket 消息契约 `contract/asyncapi.yaml`（AsyncAPI），定义 `terminal_input`/`terminal_output`/`approval_request`/`approval_response`/`ai_stream` 五类消息的载荷结构。验证：AsyncAPI 语法校验通过，五类消息均有 schema
- [x] 2.3 契约评审冻结：backend 与 frontend 实现方评审 2.1/2.2 契约并标记为 frozen（后续变更须走契约修订）。验证：评审通过记录存在、契约版本冻结
- [x] 2.4 在 `backend/` 初始化 Spring Boot 3.5.x 项目，引入 Spring AI（OpenAI 兼容 starter）、MyBatis-Plus、sqlite-jdbc、sshj、java-keyring、Flyway 依赖，并接入 `openapi-generator`（spring）从 2.1 契约生成 controller 接口/DTO。验证：`./mvnw spring-boot:run`（或 `gradlew bootRun`）启动成功且 `/actuator/health` 返回 `UP`，codegen 从冻结契约生成成功
- [x] 2.5 在 `frontend/` 初始化 Vue3 + TypeScript（Vite）项目，引入 xterm.js 与 WebSocket 客户端，并接入 `openapi-generator`（typescript）从 2.1/2.2 契约生成 API 客户端、类型与 WS 消息类型。验证：`npm run dev` 启动成功、默认页可加载，codegen 生成成功且 `npm run build` 通过
- [x] 2.6 建立后端分层目录（controller/service/mapper/entity/config/ws）与前端目录（views/components/api/stores）。验证：目录结构存在，后端仍能启动、前端 `npm run build` 通过

## 3. 数据层与迁移

- [x] 3.1 配置嵌入式 SQLite 数据源（文件置于用户数据目录、启用 WAL 模式）与 MyBatis-Plus。验证：应用启动后在用户数据目录生成 SQLite 文件，`PRAGMA journal_mode` 返回 `wal`
- [x] 3.2 编写 Flyway V1 迁移脚本，建表 `hosts`/`credentials`/`sessions`/`ai_conversations`/`ai_messages`/`approvals`/`settings`。验证：首次启动后迁移执行成功，查询 `sqlite_master` 可见全部 7 张表
- [x] 3.3 为各表创建 MyBatis-Plus 实体与 Mapper。验证：针对每个 Mapper 的最小 CRUD 单元测试通过

## 4. 凭据安全存储（credential-store）

- [x] 4.1 实现基于 java-keyring 的主密钥托管（对接 Windows DPAPI / macOS Keychain / Linux SecretService）。验证：单元测试能写入并读回主密钥
- [x] 4.2 实现凭据加解密服务（如 AES-GCM），保存前加密、使用时于内存解密。验证：单元测试——保存密码/私钥后 `credentials` 表仅存密文、无明文，解密可正确还原
- [x] 4.3 实现密钥库不可用时的明确报错路径（禁止静默明文），并提供“用户主密码派生密钥”回退。验证：单元测试——模拟密钥库不可用时抛出“凭据保护不可用”，回退路径可正常加解密
- [x] 4.4 确保明文凭据不写入日志、审计与错误信息。验证：对加解密与连接流程做日志断言，输出中不含明文凭据

## 5. 服务器配置管理（ssh-connection：配置管理）

- [x] 5.1 实现服务器配置的 REST CRUD（主机地址/端口/用户名/认证方式/分组备注，对齐 2.1 契约 `/api/hosts`），凭据经 4.2 加密存储。验证：集成测试——POST/GET/PUT/DELETE 均生效且持久化，`credentials` 表存密文
- [x] 5.2 实现前端服务器列表与配置表单（新增/编辑/删除，消费 2.5 生成的 TS 客户端/类型）。验证：新增配置后列表展示、编辑后连接使用新值、删除后不再展示（组件测试或手动验证）

## 6. SSH 连接与双通道终端（ssh-connection：连接/终端/生命周期）

- [x] 6.1 实现 sshj 连接服务，支持密码与私钥（含 passphrase）认证，凭据经 4.2 于内存解密使用。验证：对测试主机/容器的集成测试——两种认证方式均成功建立会话
- [x] 6.2 实现认证失败与主机不可达的错误处理（明确原因、不泄露内部细节、连接超时）。验证：测试——无效凭据返回“认证失败”，不可达主机超时返回“连接失败：主机不可达”
- [x] 6.3 分配交互式 PTY shell 通道，实现 WebSocket ↔ PTY 双向流式桥接（消息类型 `terminal_input`/`terminal_output`，对齐 2.2 契约）。验证：前端输入命令后实时回显 stdout/stderr
- [x] 6.4 实现前端 xterm.js 终端视图，支持彩色输出、光标控制与中断信号（Ctrl-C）转发。验证：手动测试——`top`/`vim` 正确渲染，Ctrl-C 能终止前台命令
- [x] 6.5 实现独立于 PTY 的 exec channel 原语（供 AI `run_command` 使用，返回 stdout/stderr/exit code、非交互）。验证：测试——经 exec channel 执行命令返回正确的 stdout/stderr 与退出码
- [x] 6.6 实现会话生命周期记录与资源释放（主动断开/超时/远端关闭）。验证：测试——关闭会话后 SSH 连接断开、资源释放、`sessions` 表记录结束；远端断开时前端提示并清理本地状态

## 7. 模型接入抽象层（model-provider）

- [x] 7.1 实现模型配置管理（provider/base_url/model/api_key，多配置 + 当前生效，对齐 2.1 契约 `/api/model-configs`），api_key 经 4.2 加密存储、不硬编码。验证：集成测试——新增/编辑/切换配置生效，DB 中 api_key 为密文，源码与默认配置无内置 key
- [x] 7.2 实现运行时手动构造 `ChatModel`（用当前设置项组装 base_url/api_key/model），支持 provider 切换（首个 MindIE，OpenAI 兼容）。验证：测试——切换当前配置后对话请求发往新端点
- [x] 7.3 实现思考/非思考双模式：思考模式区分 `reasoning_content` 与 `content`，非思考仅取 `content`，默认模式可配。验证：测试——思考模式返回可区分的思考过程与最终回答，非思考模式仅返回最终回答
- [x] 7.4 实现流式响应（SSE → WebSocket `ai_stream` 增量推送）与端点错误处理（不可达/错误状态明确报告）。验证：测试——流式逐步推送增量；端点不可达时报告明确错误、不静默失败
- [x] 7.5 实现前端设置页（模型配置 CRUD + 默认模式选择，消费 2.5 生成的 TS 客户端/类型），未配置 api key 即使用 AI 时提示“请先在设置中配置模型 api key”。验证：手动/组件测试——保存与切换配置生效，缺 key 时给出提示

## 8. 命令审批闸门（command-approval）

- [x] 8.1 实现审批闸门核心：生成 `approval_id`、经 WebSocket 推送 `approval_request`（含 AI 分析与待执行命令，对齐 2.2 契约）、以 `CompletableFuture` + 超时内存挂起。验证：测试——以合成触发调用审批服务时，推送 `approval_request` 并挂起等待
- [x] 8.2 实现 `approval_response` 处理：批准 → 经 6.5 exec channel 执行命令并将输出回喂；取消 → 回喂“用户已拒绝”。验证：测试——批准路径执行命令并回喂输出，取消路径回喂拒绝信息
- [x] 8.3 实现审批超时自动取消与挂起资源释放。验证：测试——超时未响应时自动按“取消”处理并释放资源
- [x] 8.4 实现命令执行的输出约束：执行超时、输出长度上限、非交互；超时中断、超限截断并明确告知。验证：测试——超时命令被中断并提示“执行超时”，超大输出被截断并标注“输出已截断”
- [x] 8.5 实现审批审计日志（`approvals` 表：时间/目标服务器/工具名与参数/AI 分析/用户决定/执行结果，不含明文凭据）。验证：测试——每次审批（批准/取消/超时）结束写入一条完整记录，且记录中无明文凭据
- [x] 8.6 实现前端审批弹框（消费 2.5 生成的 WS 消息类型；展示 AI 分析 + 待执行命令 + “执行”/“取消”按钮）。验证：手动测试——弹框出现，点击“执行”/“取消”分别驱动后端批准/取消路径

## 9. AI 智能体与工具集（ai-agent）

- [x] 9.1 依据 1.4 决策实现 `ChatClient` 手动工具执行模式（`internalToolExecutionEnabled=false`），由应用接管 `tool_calls`（或文本协议解析）。验证：测试——智能体请求工具时不被框架自动执行，而交由应用路由
- [x] 9.2 实现只读工具 `@Tool`：`list_dir`、`read_file`（带行数上限）、`system_info`，经 6.5 exec channel 执行、自动无需审批。验证：测试——只读工具自动执行并回喂结果，`read_file` 超限行数被截断
- [x] 9.3 实现副作用工具 `@Tool`：`run_command`，被拦截转入第 8 组审批闸门、不直接执行。验证：测试——调用 `run_command` 时生成审批请求而非立即执行
- [x] 9.4 实现智能体多轮对话循环与会话上下文持久化（`ai_conversations`/`ai_messages`）。验证：测试——同会话多轮追问基于此前上下文回应，消息正确落库
- [x] 9.5 实现操作透明性：记录并展示每次工具调用（工具名/参数/结果或“用户已拒绝”）。验证：`ai_messages` 落库含工具调用明细，前端可见
- [x] 9.6 实现前端 AI 对话面板（流式展示、思考过程与最终回答区分、工具调用可视化，消费 2.5 生成的 WS 消息类型）。验证：手动测试——提问后流式展示、思考/回答分区、工具调用可见

## 10. 端到端验证与安全门禁

- [x] 10.1 端到端场景验证：配置主机 + 模型 → 连接交互式终端 → 向 AI 提运维问题 → 只读工具自动执行 → `run_command` 触发审批 → 批准后执行并回喂 → 结果展示。验证：该完整流程在本地 Web（`localhost`）跑通
- [x] 10.2 运行 `openspec validate add-ssh-ai-agent-mvp --strict` 确认工件与实现一致、无校验错误。验证：命令退出码为 0
- [x] 10.3 安全核查：确认无明文/硬编码 api key 与凭据、DB 仅存密文、日志无明文。验证：`/security-scan` 无高危发现，人工核查凭据存储与日志路径

## 归档核查记录（2026-09-22）

用户已试用核心流程，并在展示未完成项和差异后明确选择“同步并带警告归档”。本次仅整理规则、同步规格并归档，没有修改业务代码、提交或推送 Git。

### 任务与规格边界
- 原始任务为 41 项已勾选、4 项未勾选；保留勾选状态，不补造历史验收证据。
- 1.1–1.4 的 MindIE tools/tool_calls、思考字段共存、文本降级验证及决策记录仍未完成。当前原生工具调用实现和其他端点试用不能代替 MindIE 专项实测。
- 2.5 的 REST 代码生成已落地；WS 类型实际是手写并由契约测试约束，未实现 AsyncAPI 自动生成。
- 4.3 的主密码回退仅有底层派生加解密方法，尚无设置、解锁及业务凭据通道；密钥库不可用时明确拒绝明文的路径已存在。
- 8.5 / 10.3 不能解释为全面安全验收通过：审批参数、分析和执行输出仍原样持久化，命令中携带的秘密缺少完整脱敏链路；本轮未重新运行云安全扫描。
- 8.6 与 command-approval 两个用户决策场景仍使用“弹框”措辞，实际入口已为用户认可的非阻断 ApprovalCard。主规格同步保留原文，后续呈现方式修订须显式处理，不在归档时偷偷改需求。
- 6.6 的前端远端关闭/WS 断线状态清理及路由复用仍需完善；基础后端资源释放测试通过不等于全部 UI 恢复路径完备。
- 同步 5 个 capability 的 21 条需求；Purpose 和场景保留。归档不代表规格全部实现，也不解除合并/发布质量门禁。

### 尚需后续变更的重点
- SSH：主机指纹首次确认/known_hosts/变更拒绝尚未实现；远端 PTY resize 底层存在，但当前 WS 契约未开放，属于已延期能力。
- 终端/UI：自动重连、多会话标签/分屏、路由参数变化、聊天历史响应竞争、健康状态真实校验；旧 AiChatView/ApprovalModal 与活跃入口需收敛，Agent 测试需覆盖 TerminalView。
- 审批/AI：并发审批卡片队列、断线决策反馈、重连待审批补发、AI 中止/恢复、长会话上下文预算。
- 文件：SFTP 上传下载/文件面板、大文件分片阅读完整工作流、修改前备份/差异预览/回滚尚未实现；现有 read_file 支持起始行和行数上限，不是空壳。
- 发布：本地端口的生产访问边界、Windows 安装包/运行时/升级、Windows 7/10/11 兼容矩阵尚未完成；不开发其他远端操作系统或 Linux/macOS 客户端。

### 本轮验证证据
| 命令 | 结果与边界 |
| --- | --- |
| `npm --prefix frontend run type-check` | 通过 |
| `node frontend/node_modules/vitest/vitest.mjs run --root F:/project/dev/workspace/AnanoesisShell/frontend --no-cache` | 14 个测试文件、128 项通过 |
| `npm --prefix frontend run build` | 通过，98 个模块转换完成 |
| `.\backend\mvnw.cmd -f backend/pom.xml -B test` | 443 项，失败 0、错误 0、跳过 0；BUILD SUCCESS |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-structure.ps1 -Root .` | 必备结构与子模块初始化检查通过；显式 Root 避免本次调用环境的默认路径为空问题 |
| `openspec validate add-ssh-ai-agent-mvp --strict` | 通过；只证明工件结构合法，不证明实现无缺口 |
| `git diff --check` | 通过；不替代未跟踪文件检查或业务测试 |

公共规则与 AGENTS 的技术栈说明已复核；本轮不重复真实 Linux/模型 E2E，也未验证 Windows 7/10/11 安装。代码仍有未跟踪内容，归档不会自动将前后端实现保存到 Git。
