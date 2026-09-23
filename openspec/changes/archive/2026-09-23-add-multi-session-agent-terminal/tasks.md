## 1. 实施前置与技术验证

本文仅为待执行清单，所有复选框保持未完成直至 apply 阶段取得验证证据；不授权提交、推送或归档。实现遵循 test-driven-development：每项先补失败测试、确认预期失败，再最小实现并运行同一测试转绿。技术验证失败须停止相关实现并修订设计，不以分离 exec 替代共享 PTY。

路径均相对仓库根。为明确文件位置，下文 `B/` 固定表示 `backend/src/main/java/com/ananoesis/shell/`，`BT/` 表示 `backend/src/test/java/com/ananoesis/shell/`，`F/` 表示 `frontend/src/`；不是待选择目录。命令在仓库根的 PowerShell 执行，各条独立检查退出码，不使用 `&&`。定向测试示例为 `backend/mvnw.cmd -f backend/pom.xml "-Dtest=AgentContextBuilderTest" test` 与 `npm --prefix frontend test -- src/components/terminal/__tests__/TerminalTimeline.spec.ts`；其余任务使用各自列明的测试类或文件运行，验收须同时满足对应行为断言与退出码 0。

- [x] 1.1 阅读 `AGENTS.md`、`.qoder/known-issues.md`、`.qoder/rules/`、本变更八份规格和 design；进入隔离开发区前记录三仓状态及分支，按现有规则建立同名 feature 分支；验证 `git status --short`、`git -C frontend branch --show-current`、`git -C backend branch --show-current`，不覆盖现有未提交工作。
- [x] 1.2 记录原始回归基线，分别运行 `backend/mvnw.cmd -f backend/pom.xml test`、`npm --prefix frontend test`、`npm --prefix frontend run type-check`、`npm --prefix frontend run build`；验证退出码及失败明细，旧测试数量只作基线，不作为本次功能验收。
- [ ] 1.3 在 `BT/ssh/ShellIntegrationProbeTest.java` 建立共享 Bash 的会话级测试探针，覆盖 `cd/export`、非零退出码、已有 DEBUG/PROMPT_COMMAND、嵌套 Shell、半行输入、多行粘贴、Ctrl-C；使用真实 Linux Bash 4+ 环境证明状态与 cwd/env 连续且不改永久启动文件，假 SSHD 不替代真实 Shell 验证。
- [ ] 1.4 在 `F/components/terminal/__tests__/TerminalTimeline.spec.ts` 与浏览器验证页验证“封存段＋一个活动 xterm”，保持 ANSI、提示符、选择复制、中文宽字符、vim/top 备用屏幕和 resize；记录视频/截图与测试断言，确认无第二聊天页面、无重复输出、无内部 canvas DOM 注入。
- [ ] 1.5 根据 1.3/1.4 证据在本变更 `design.md` 固化控制帧格式、边界握手与展示段续接方法；若确需序列化 addon，仅在 `frontend/package.json`、`frontend/package-lock.json` 锁定与 xterm 5 主版本匹配的版本并重跑 1.4，不引入 UI 框架；没有通过证据则相关任务保持未勾选。

## 2. 契约版本二与生成边界

- [x] 2.1 在 `contract/openapi.yaml` 定义 session 创建返回一次性 control_token、连接级鉴权、创建/选择活动对话、列表及消息游标包装、单删/批删和模型预算字段；逐项验证绑定关系、400/403/404/409 及旧客户端版本错误示例，不允许 host 参数覆盖执行目标。
- [x] 2.2 在 `contract/openapi.yaml` 定义 D9 全部文件/传输端点、queued/ready/传输/发布/终态、ready_deadline、expected_target、字节计数、限流及票据规则；明确 PUT octet-stream、下载附件头、单文件上限及 JSON 控制面，验证上传/下载/冲突/取消请求响应示例均能按契约解释。
- [x] 2.3 在 `contract/asyncapi.yaml` 定义 v2 bind、resize、stop、活动对话变更事件、订阅快照、命令事件、context_notice、attempt_reset、审批修改与回执；事件携带 session/run/call/command/approval-version/event_seq/attempt 归属，验证跨连接、重复和过期事件均有拒绝或忽略规则。
- [x] 2.4 调整 `backend/pom.xml` 与 `frontend/openapitools.json` 的生成集合，仅排除 `TransferContent` 二进制 tag；运行 `backend/mvnw.cmd -f backend/pom.xml generate-sources` 与 `npm --prefix frontend run codegen`，验证 JSON 接口/DTO/客户端仍生成、二进制适配器不被生成物覆盖，不手改生成代码。
- [x] 2.5 更新 `F/types/ws-messages.ts`、`F/types/__tests__/ws-messages.spec.ts`，新增 `BT/controller/TransferContentContractTest.java`；验证 WS 字段/枚举与契约一致，手写 PUT/GET 的路径、媒体类型、鉴权、状态码及附件头均在 OpenAPI 中有定义。
- [x] 2.6 更新 `contract/TRACEABILITY.md`，将八个 capability 的每条 Requirement/Scenario 映射到本清单任务和测试文件；验证无未关联场景，明确二进制流式适配例外，不将旧 MVP 未完成项目标成已完成。

## 3. 增量数据库迁移与实体

- [x] 3.1 扩展 `BT/datastore/SqliteSchemaMigrationTest.java`，以含原聊天、凭据引用与审批的 V1 数据库为夹具，新增 V2 升级失败测试；验证旧消息内容、数量、UUID、时间与外键语义不丢失，旧 conversation 的 session_id 为 NULL。
- [x] 3.2 新增 `backend/src/main/resources/db/migration/V2__session_workspace_and_transfers.sql`：conversation/session 绑定、消息 source/command/run、ai_runs、command_executions、approval_revisions、file_transfers、审批版本字段；验证 3.1 转绿及 `FlywayMigrationPurityTest`，不得重写 V1 或在 SQL 存秘密/使用 JSON 扩展迁移模型配置。
- [x] 3.3 在 `B/entity/` 新增 `AiRun.java`、`CommandExecution.java`、`ApprovalRevision.java`、`FileTransfer.java`，在 `B/mapper/` 新增四个同名 Mapper；同步既有消息/对话/审批实体，新增 `BT/mapper/WorkspaceMapperTest.java` 验证 CRUD、状态 CHECK、自动工具 `(run_id,call_id)` 唯一及每 session 一个活动 run。
- [x] 3.4 在 3.2 的未发布 V2 中完善对话/消息 SET NULL、命令目标快照及分页/传输索引；扩展 `BT/datastore/SqliteSchemaMigrationTest.java` 验证删除对话只级联消息、账本和审批仍可查询，查询计划命中分页索引，不执行自动 VACUUM。

## 4. 连接运行时、控制能力与事件生命周期

- [x] 4.1 新增 `B/ssh/SessionRuntime.java`，改造 `B/ssh/SshTerminalService.java`、`B/ssh/SshTerminalSession.java`，以 session_id 而非 host_id 管理 transport/PTY；新增 `BT/ssh/SessionRuntimeTest.java` 验证同主机两次连接得到不同资源，关闭一条不影响另一条。
- [x] 4.2 新增 `B/security/SessionControlService.java` 并接入会话控制接口及 `B/ws/TerminalWebSocketHandler.java`、`AiWebSocketHandler.java`、`ApprovalWebSocketHandler.java`；新增 `BT/security/SessionControlServiceTest.java` 验证 256-bit 凭证仅散列留存、首帧绑定/10 秒超时、跨实例资源拒绝、GET 不误要求 JSON、PUT 类型校验正确。
- [x] 4.3 在 `B/ssh/SessionRuntime.java` 实现单调事件序号、1 MiB 尾部与独立审批快照，新增 `BT/ws/WorkspaceSubscriptionTest.java`；验证重新订阅无重复更新、超出尾部明确输出缺口、待审批不因尾部截断消失，历史查询不需要已销毁 runtime 凭证。
- [x] 4.4 实现控制端短断线 30 秒宽限和显式关闭清算，扩展 `BT/ssh/SessionRuntimeTest.java` 使用可控时钟验证重连、到期、远端关闭与重复关闭；先禁止新任务再清算，仅释放所属资源，浏览器刷新不承诺会话恢复。
- [x] 4.5 在终端 WS handler 加入有效行列校验和所属 PTY resize，扩展 `BT/ws/WorkspaceSubscriptionTest.java` 验证零/负/异常尺寸拒绝、同主机另一连接未收到尺寸更新、v1 客户端收到明确版本错误。

## 5. 持久 Shell 集成与输入调度

- [x] 5.1 新增 `B/ssh/ShellFrameDecoder.java` 与 `BT/ssh/ShellFrameDecoderTest.java`；按 1.5 固化格式先测试任意分片、连续帧、非法长度、错误 nonce、中文边界及普通 OSC，再实现有界解析，验证内部帧不显示且无无限缓冲。
- [x] 5.2 新增 `B/ssh/ShellIntegration.java`，将 1.3 探针收敛到会话级安装及身份/命令/cwd/exit 帧；新增 `BT/ssh/ShellIntegrationTest.java` 验证退出码在钩子处理前保存、现有钩子不被破坏、不支持的 Shell 明确禁用自动工具且人工/SFTP 不受影响。
- [x] 5.3 新增 `B/ssh/PtyCommandScheduler.java` 与 `BT/ssh/PtyCommandSchedulerTest.java`，实现 manual_idle/manual_busy/agent_owned/stopping/unknown 转换；验证半行、粘贴、全屏、嵌套 Shell、失去钩子时没有 Agent 字节写入，只有已确认空提示符才领取输入权。
- [x] 5.4 在调度器接入 60 秒超时、64 KiB 采集、超额持续排空及中断后 3 秒判 unknown；扩展 `BT/ssh/PtyCommandSchedulerTest.java` 验证大输出不堵塞、未知状态不自动推进、Ctrl-C 不是完成证据。
- [x] 5.5 改造 `B/ai/AgentTools.java` 与 `B/approval/ApprovedCommandRunner.java`，将全部远端工具路由到绑定 session 的持久 PTY；扩展 `BT/ai/AgentToolsTest.java` 验证 `cd/export` 继承、工具参数安全引用、只读工具不能借参数拼接执行额外命令，新 Agent 路径不调用 SshExecService。

## 6. 运行账本与版本化审批

- [x] 6.1 新增 `B/service/AgentRunService.java` 与 `BT/ai/AgentRunServiceTest.java`，以数据库活动唯一性及 session 串行裁决领取 run；验证同 session 不同 conversation 不能并行执行、不同 session 可并行，模型配置快照在 run 开始冻结。
- [x] 6.2 改造 `B/ai/AiAgentService.java`，先落库 assistant 工具提议及稳定 call_id，再进入审批/执行，再持久化真实结果；新增 `BT/ai/AgentExecutionLedgerTest.java` 验证 SQLite 事务不跨网络/审批等待、工具失败和拒绝不会伪造成功结果。
- [x] 6.3 将执行领取、发送、完成及 unknown 接入 `B/approval/ApprovedCommandRunner.java` 和命令账本；扩展 `BT/ai/AgentExecutionLedgerTest.java` 注入领取后崩溃、PTY 写入结果不明、结果落库失败及重复调用，验证不会自动重写命令。
- [x] 6.4 改造 `B/approval/ApprovalGate.java` 和 `B/ws/ApprovalWebSocketHandler.java`，新增不可变 revision、expected_version、修改后再次批准；新增 `BT/approval/ApprovalRevisionTest.java` 验证旧版本失效、原到期时间不延长、实际执行及工具结果对应修改后的命令。
- [x] 6.5 扩展 `BT/approval/ApprovalGateIntegrationTest.java`，对批准/拒绝/修改/超时/停止/关闭做并发栅栏测试；实现同一调度器内互斥裁决，验证只有一个合法领取、重复消息返回当前状态或 409，两个 tab 审批不相互覆盖。
- [x] 6.6 在 `B/service/AgentRunService.java` 实现取消代次和停止流程，新增 `BT/ai/AgentStopTest.java`；验证先阻断新写入、再取消模型及待审批、再中断清算，晚到流事件不能执行工具，未确认结束显示 unknown 而非已回滚。
- [x] 6.7 扩展 `BT/controller/ApprovalsApiIntegrationTest.java` 与新增 `BT/security/WorkspaceAuditRedactionTest.java`，实现查询最终命令/版本/目标快照及敏感值遮蔽；验证删除聊天后审计可查、控制凭证/登录交互/已知密钥不落库不出日志，不把任意秘密自动识别视为已解决。

## 7. 人工记忆与有界历史管理

- [x] 7.1 改造 `B/service/ConversationService.java`，持久化完成的人工命令为 user/shell_event、关联 command_id/run_id；新增 `BT/ai/ShellMemoryTest.java` 验证同 tab 人工结果可供下一问题引用、不跨 tab、不记每次按键/密码交互、不伪造工具调用。
- [x] 7.2 将 conversation 创建/“继续此对话”绑定 session 并通过调度器改变活动引用；扩展 `BT/ai/ShellMemoryTest.java` 验证只有空闲同 session 可切换，浏览历史不改变执行目标，新对话不复制旧记录。
- [x] 7.3 实现列表 `(created_at,id)` 与消息 `(seq,id)` keyset 查询、游标筛选及首屏上界；扩展 `BT/controller/ConversationsApiIntegrationTest.java` 验证默认 30/50、最大 100/200、非法游标拒绝、新增记录不会打乱当前分页、无全量读库再切片。
- [x] 7.4 实现单删与最多 100 项批删，按稳定顺序锁定涉及的 session 并在短事务内校验/删除；新增 `BT/controller/ConversationDeletionTest.java` 验证任一 generating/executing/waiting_approval/stopping 导致全不删，空闲和已清算 unknown 可删，审计与账本保留。
- [x] 7.5 同步清空被删活动引用并使用取消/请求代次拦截旧回调；扩展 `BT/controller/ConversationDeletionTest.java` 验证删除不调用模型、后续人工命令/提问创建新对话、晚到回调不复活记录、旧关闭连接历史无需旧 control_token 仍可查询删除。

## 8. 模型配置与每次调用上下文预算

- [x] 8.1 改造 `B/service/ModelConfigService.java`、`B/ai/ModelEndpointResolver.java`、`B/ai/ConfiguredModelEndpointResolver.java` 和 `B/ai/OpenAiCompatibleChatModelProvider.java`，增加容量/输出/字段选择/思考扩展；扩展 `BT/controller/ModelConfigsApiIntegrationTest.java` 验证默认 8192/1024、容量范围、输入预算至少 512、非法整数拒绝，新建密钥必填及编辑留空保留。
- [x] 8.2 在 `B/service/ModelConfigService.java` 实现旧 settings JSON 幂等迁移：openai 为 none，其余旧值为 qwen_compatible；新增 `BT/ai/ModelConfigMigrationTest.java` 验证新配置默认 none、旧行为不丢、迁移重复运行不再改写、凭据引用和自定义名称保留。
- [x] 8.3 新增 `B/ai/ContextTokenEstimator.java` 与 `BT/ai/ContextTokenEstimatorTest.java`，按 D7 计完整 messages/tools/结构 UTF-8 字节及余量；验证中文、代码、JSON、工具定义、系统状态和输出预算全部计入，不使用字符除四或声称精确 tokenizer。
- [x] 8.4 新增 `B/ai/AgentContextBuilder.java`，在 `B/service/ConversationService.java` 增加 seq 水位约束的倒序 LIMIT 60 查询；新增 `BT/ai/AgentContextBuilderTest.java` 验证 61/10000 条历史都只读取最近候选、含工具和本轮消息、不会删除 DB 或回补第 61 条。
- [x] 8.5 在上下文构建器实现完整 assistant/call_id/tool 原子组校验；扩展 `BT/ai/AgentContextBuilderTest.java` 验证边界残组、多调用少一结果、重复结果、孤立结果整组排除，当前问题脱离窗口时明确停止，不用相邻检查冒充配对。
- [x] 8.6 实现单结果最多输入预算四分之一的头尾投影和从旧到新的完整组淘汰；扩展 `BT/ai/AgentContextBuilderTest.java` 验证十条长输出也缩减、当前问题与最近必要执行组受保护、JSON/call_id 不截断、最小请求不容纳时不发模型请求、原持久内容不被改写。
- [x] 8.7 改造 `B/ai/AiAgentService.java`，每次模型调用都从持久化快照重建上下文并发 context_notice；扩展 `BT/ai/AiAgentServiceTest.java` 验证工具循环后重新预算、保留八轮上限、用户消息不重复保存、SFTP 内容从不自动入模。
- [x] 8.8 扩展 `BT/ai/OpenAiCompatibleChatModelProviderTest.java`，验证 max_tokens/max_completion_tokens 只发送一个、扩展由显式配置决定而非供应商名称、三类供应商使用同一兼容路径、编辑配置不改变在途 run；不新增 MindIE 专项或原生 Ollama adapter。

## 9. 上下文超限受控恢复

- [x] 9.1 新增 `B/ai/ContextLimitClassifier.java` 与 `BT/ai/ContextLimitClassifierTest.java`，覆盖明确错误码/token 超限语义；验证普通 400/413、401、网络异常、未知参数与 finish_reason=length 均不触发上下文恢复。
- [x] 9.2 将每 run 一次恢复额度、固定 seq 快照和输入预算减半接入 `B/ai/AiAgentService.java`；新增 `BT/ai/AgentContextRecoveryTest.java` 验证第二次超限停止、额度跨工具轮次共享、最小请求无法容纳时不重试、不重新落库用户问题。
- [x] 9.3 在 `BT/ai/AgentContextRecoveryTest.java` 注入“命令已成功、下一模型调用超限、恢复成功”的完整链路；验证 PTY 命令发送计数不增加、账本不重领、失败尝试中的未完成 tool_calls 不进入路由，恢复产生的新有效调用仍走原审批规则。

## 10. 多 tab 工作区与统一终端界面

- [x] 10.1 新增 `F/stores/workspaces.ts`、`F/runtime/workspace-runtime.ts` 及 `F/stores/__tests__/workspaces.spec.ts`；按 session 保存 runtime/token/草稿/模式/审批/文件路径，验证 A #1、A #2、B #1 三个独立实例，临时失败 tab 可重试且不按 host 去重。
- [x] 10.2 新增 `F/views/WorkspaceView.vue`，调整 `F/App.vue`、`F/router/index.ts`、`F/views/ServerListView.vue`、`F/views/TerminalView.vue`；新增 `F/views/__tests__/WorkspaceView.spec.ts` 验证路由仅切显示、进入设置不销毁后台资源、显式关闭才清算，生产入口不再使用全局单槽 ApprovalCard。
- [x] 10.3 将 1.4 验证方案落实至 `F/components/terminal/TerminalTimeline.vue`；扩展同目录 `__tests__/TerminalTimeline.spec.ts` 验证已完成段/活动段/DOM 分析顺序、PTY 字节只显示一次、全屏期间不插卡、10,000 行和 8 MiB 上限提示而非伪装完整回放。
- [x] 10.4 新增 `F/components/terminal/AgentInput.vue` 与 `__tests__/AgentInput.spec.ts`；验证同底部输入区切换模式、自然语言不进 PTY、两种草稿保留、人工半行不自动提交、agent_owned 禁止普通按键但可停止。
- [x] 10.5 新增 `F/components/terminal/InlineApprovalCard.vue` 与 `__tests__/InlineApprovalCard.spec.ts`；验证执行/修改/拒绝、展示最终版本、修改后必须再次执行、按钮等待服务端回执、断线不假装已批准、后台数量正确。
- [x] 10.6 完成 `F/runtime/workspace-runtime.ts` 的定向订阅、重连与 resize，扩展 `F/runtime/__tests__/workspace-runtime.spec.ts`；验证后台事件不改前台内容、快照去重、尾部缺失提示、隐藏实例不发零尺寸、关闭后定时器/监听/终端被释放。
- [ ] 10.7 在 `F/views/__tests__/WorkspaceView.spec.ts` 与浏览器键盘检查中覆盖 tab roving tabindex、模式/审批控件焦点、取消返回及关闭相邻焦点；验证异步输出不抢焦点、状态不只靠颜色、播报节流且终端方向键不被 tab 导航截获；文件队列焦点验证随 14.6 接入。
- [ ] 10.8 在恢复事件中区分 attempt_id，扩展 `F/runtime/__tests__/workspace-runtime.spec.ts` 的 attempt_reset 场景并实现对应呈现；验证仅撤回失败尝试的未完成分析、不撤回真实命令段、不拼接旧片段，新失败提示不泄露系统指令或密钥。

## 11. 历史面板与供应商界面

- [x] 11.1 新增 `F/components/ConversationHistory.vue` 与 `__tests__/ConversationHistory.spec.ts`，使用生成客户端进行筛选、分页、消息/工具记录展示；验证关闭连接和无 session 旧历史只读、加载更多保序、快速切换晚到响应无效、查看不改变运行中会话。
- [x] 11.2 接入同 session 空闲时“继续此对话”、单删/批删确认与失败保留；扩展 `F/components/__tests__/ConversationHistory.spec.ts` 验证最多 100 项、409 显示先停止清算、删除当前对话为空白但不自动发问，已删除记录不被旧响应复活。
- [x] 11.3 改造 `F/components/ModelConfigForm.vue`、`F/components/__tests__/ModelConfigForm.spec.ts`、`F/stores/modelConfigs.ts`；验证空白仅占位不可保存、openai/ollama 规范值、其他名称完整回填且非空、切换选项不覆盖地址/模型/密钥、不把 other 当持久值。
- [x] 11.4 在 `F/components/ModelConfigForm.vue` 提供 context_window_tokens/max_output_tokens/output_limit_field/thinking_request_format 与预算说明；扩展 `F/components/__tests__/ModelConfigForm.spec.ts` 验证错误边界、保守估算提示、旧配置回填、新建密钥语义及编辑留空保留，Ollama 不被误宣传为新增免鉴权模式。

## 12. SFTP 路径与远端目录浏览

- [x] 12.1 在 `backend/pom.xml` 仅增加与现有 Apache SSHD 同版本的 test-scope `sshd-sftp`，新增 `BT/ssh/SftpTestServer.java` 和 `BT/ssh/SftpServiceTest.java`；验证内嵌服务器能建立 SFTP、拒绝 subsystem 和故障注入，不增加生产 SSH 框架。
- [x] 12.2 新增 `B/ssh/SftpService.java`，通过 SessionRuntime 获取 transport 并按任务分配独立 subsystem；实现路径逐层 lstat、普通文件校验及 basename 校验，验证中文/空格、NUL/CR/LF、分隔符、链接链路、设备/FIFO/socket 拒绝，不拼接 Shell 命令。
- [x] 12.3 实现有界 READDIR、默认 100 最大 200、路径/session/handle 绑定游标及每连接两个目录 handle/30 秒过期；扩展 `BT/ssh/SftpServiceTest.java` 验证大目录不全量 ls、刷新/换目录释放句柄、失效游标明确提示、无权限不伪装空列表。
- [x] 12.4 新增 `B/controller/FilesApiController.java` 接入生成接口，新增 `BT/controller/FilesApiIntegrationTest.java`；验证两个同主机 session 独立浏览、跨 session 凭证拒绝、无 SFTP 时明确失败且不影响人工 PTY。

## 13. SFTP 调度、流式上传与发布

- [x] 13.1 新增 `B/service/TransferService.java`、`B/controller/TransfersApiController.java` 与 `BT/ssh/TransferSchedulingTest.java`；按 D9 状态机实现全局有界队列和配额，验证 ready 也占配额、每 session 2/全局 4/排队 100、超限 429、队列不打开通道、不接收正文。
- [x] 13.2 在 TransferService 实现 ready 30 秒领取租期与原子领取；扩展 `BT/ssh/TransferSchedulingTest.java` 验证 queued 超过 30 秒仍未发票、ready 到期释放、重复 PUT/并发 GET 至多一个流、transferring/终态不可重新启动，排队取消即时生效。
- [x] 13.3 新增 `B/controller/TransferContentController.java` 与 `B/config/TransferProperties.java`，上传用 servlet 原始输入流及 64 KiB 固定缓冲；新增 `BT/controller/TransferUploadTest.java` 验证默认 10 GiB 上限可配置、零字节、实际与声明不符、超限拒绝、无 multipart/全量 byte[]/日志正文。
- [x] 13.4 在 SftpService/TransferService 实现同目录独占临时文件、0600 默认权限、写完关闭及大小核验、no-replace rename；新增 `BT/ssh/TransferPublicationTest.java` 验证最终文件发布前不可见、默认不覆盖、临时名冲突不截断他人文件、失败仅清理自身临时文件。
- [x] 13.5 实现创建冲突 409 返回目标快照、用户确认后的 expected_target 校验、发布前复核与原子替换能力检查；扩展 `BT/ssh/TransferPublicationTest.java` 验证目标变化 target_changed、权限保留/设置失败不发布、不支持安全替换拒绝、无先删除原文件操作，不假设存在 CAS。
- [x] 13.6 将取消裁决与流式 I/O 执行线程分离；扩展 `BT/ssh/TransferPublicationTest.java` 注入阻塞 WRITE、取消/publishing 竞争、rename 响应丢失，验证可停止单通道、publishing 不能虚报取消、published 不被删除、unknown 不自动重传且清理待办可追踪。

## 14. SFTP 下载、故障隔离与前端队列

- [x] 14.1 新增 `B/security/DownloadTicketService.java` 和 `BT/security/DownloadTicketServiceTest.java`；验证仅 ready 可领票、散列存储、最长 30 秒且不越 ready_deadline、换票旧票失效、消费与任务领取原子化、跨 transfer/过期/重复票据拒绝。
- [x] 14.2 在 `B/controller/TransferContentController.java` 实现有界异步附件响应，在 `B/config/TransferProperties.java` 配置固定上限执行器；新增 `BT/controller/TransferDownloadTest.java` 验证真实 HTTP 慢客户端背压、中文 filename*、ASCII fallback、Windows 保留名和头注入处理、no-store/no-referrer、正文不整体缓存在堆内。
- [x] 14.3 在传输服务实现进度更新、从 transferring 开始的连续 120 秒停滞计时、连接关闭与重启清算；新增 `BT/ssh/TransferFailureTest.java` 覆盖磁盘满、权限错误、HTTP 断开、subsystem 关闭、清理失败，验证总时长超过 120 秒但持续进展不超时、其他 PTY/任务仍可用、已发送下载仅为 delivered。
- [x] 14.4 新增 `F/components/files/RemoteFilePanel.vue` 与 `__tests__/RemoteFilePanel.spec.ts`；接入目录浏览、父目录、刷新、加载更多、多文件选择和逐文件下载，验证切 tab 路径隔离、链接/非普通文件不可传、所有错误显式呈现，上传始终使用选择时展示的目标快照。
- [x] 14.5 新增 `F/components/files/TransferQueue.vue`、`F/api/transfer-content.ts` 和 `F/api/__tests__/transfer-content.spec.ts`；JSON 控制用生成客户端、正文用 XHR/File 及普通附件导航，验证 ready 才启流/领票、不转整个 Blob/base64、上传发送进度与远端进度分开、每秒轮询并在关闭/终态释放。
- [x] 14.6 新增 `F/components/files/__tests__/TransferQueue.spec.ts`，接入每文件覆盖确认、重试新任务和取消回执；验证确认不影响其他同名文件、显示并发修改风险、取消不提前宣称成功、unknown 不自动重试，下载完成文案为“已交给浏览器”而非已验证落盘；键盘可访问每个任务操作，取消/确认后焦点回到对应任务，进度播报节流。
- [x] 14.7 扩展 `BT/controller/TransferContentContractTest.java` 与 `F/api/__tests__/transfer-content.spec.ts`，验证 ticket/control_token 不进日志或持久前端存储、票据 GET 不接受通用执行操作、本地绝对路径不被后端用于磁盘读写、上传下载内容不流入模型和审计正文。

## 15. 跨模块验收与资源上限

- [ ] 15.1 在真实 Linux Bash 与浏览器联调同主机 A #1/A #2 和 B #1：人工 cd/export 后 Agent 引用结果并获批执行、修改审批、拒绝、后台等待及设置页往返；验证独立 cwd/env/草稿/审批、同一终端连续呈现、输出仅一次，保存验收截图及命令发送计数证据。
- [ ] 15.2 联调 vim/top、嵌套 Shell、半行输入、resize、Ctrl-C、生成中停止、审批与关闭竞态及短断线；验证无命令注入交互程序、30 秒宽限、停止后晚到事件无执行权、unknown 明示、不支持 Shell 仍能人工与 SFTP。
- [ ] 15.3 使用受控 OpenAI 兼容测试端点触发少于 60 条超预算及命令后的服务端超限；验证一次恢复、固定快照、不重跑远端工具、失败文本重置、旧历史仍可分页和手动删除，活动对话批删全不删；不要求 MindIE 品牌验收。
- [ ] 15.4 浏览器上传/下载中文名、空文件、随机二进制和超过 10 MiB 的文件，用本地及下载后 SHA-256 比较；后端与浏览器分处不同电脑验证下载确实交付浏览器机器，保存目录由浏览器决定，不使用后端路径冒充本地下载。
- [ ] 15.5 在隔离测试目录对受支持 Linux SFTP 服务执行 1 GiB 及配置上限 10 GiB 传输、取消和多连接并发；记录前后端峰值内存/句柄/任务数，验证固定缓冲与配额、不随整个文件线性驻留，重复传输结束后资源回落；空间不足应记录阻塞，不可用小文件代替该验收打勾。
- [ ] 15.6 对 `frontend/vite.config.ts` 开发代理做真实二进制传输；如实际部署使用反向代理，按 D9 校验请求体上限、禁全量缓冲和空闲超时，分别测试直连和代理的大文件/慢客户端/取消，不因 multipart 默认值或代理造成隐藏失败。
- [ ] 15.7 故障注入覆盖重名目标并发变化、无原子替换、磁盘满、票据重复、排队取消、上传发布响应丢失、后台 tab 长输出和浏览器断开；验证原文件不被预删、无自动重传、清理未完成可见，取消一个传输不关闭终端或其他连接。

## 16. 回归、迁移演练与交付门禁

- [x] 16.1 运行 `backend/mvnw.cmd -f backend/pom.xml test`、`npm --prefix frontend test`、`npm --prefix frontend run type-check`、`npm --prefix frontend run build`，分别保存最新退出码和汇总；验证新增及既有功能全部通过，不以此前 128/443 的历史数量替代本次结果。
- [ ] 16.2 在测试数据副本上演练 design Migration Plan：在线完整备份或停库备份含 WAL 状态、V1→V2 升级、旧模型 JSON 迁移、旧历史只读、在途账本清算及配套版本回退；验证凭据仍可用、历史不丢、无自动重放/远端回滚/破坏性 down migration。
- [ ] 16.3 按实际修改范围执行 Java、TypeScript/Vue 与安全评审，覆盖 SQL/状态机、XSS/输出来源、凭证/票据、跨连接控制、流式资源和审批绕过；逐项解决高风险问题并重跑相关测试，既有 known_hosts/任意秘密识别/完整应用认证欠账仍明确列为发布门禁。
- [x] 16.4 实现验收后更新 `backend/README.md`、`frontend/README.md`、`AGENTS.md` 和 `.qoder/rules/frontend-ui.md`、`backend-standards.md`、`database-standards.md` 中受本变更影响的基线及二进制流式例外，保留中文 WHY 注释；验证文档与实现一致、Windows 7/10/11 安装兼容没有被 Web 验收冒充完成。（实做：两份 README 从 3 行骨架补齐为真实基线（技术栈/目录地图/运行测试命令，已与 vite.config.ts、pom.xml 核对一致）；frontend-ui.md 基线句改 WorkspaceView/TerminalTimeline 并新增 Ctrl+C 本地闭环两条约束；backend-standards.md 新增取消入口/包装异常识别/中断标志决策两条；database-standards.md 依据句改 V1/V2；AGENTS.md 经核对已是栈锁定后版本无过时表述，未动；Win7/10/11 安装兼容仍在 AGENTS.md 明示为未验证，未冒充完成）
- [x] 16.5 运行 `openspec validate add-multi-session-agent-terminal --strict`、`openspec validate --all --strict`、`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-structure.ps1 -Root .` 及三仓 `git diff --check`；复核 `contract/TRACEABILITY.md` 的全部场景实现/测试对应，无未解决漂移再交付。（实测：单变更与 --all 均 valid、6 passed 0 failed；verify-structure 通过且两子仓在 feature 分支；三仓 diff --check 干净；TRACEABILITY 已补登 stop_turn 上行帧与「Agent 生成中 Ctrl+C 即时打断」场景行）
- [ ] 16.6 汇总真实完成任务、测试证据、Bash 支持边界、SFTP 发布竞态/本地落盘语义及仍待发布整改的风险；核对本清单全部证据后向用户交付，不擅自提交、推送或归档。后续只有用户另行指令才同步主规格/归档，并显式修订 ssh-connection Purpose 的“单台”范围，不重写旧 MVP 历史记录。

## 17. 验收期用户反馈新增需求（已实现并回写规格，以代码为准）

用户授权自主收尾后，实测中追加两项需求，均已按 TDD 实现并回写对应 delta spec：

- [x] 17.1 终端集成静默安装（用户反馈“每次第一次连接都会打印这些东西”）：`B/ssh/ShellIntegration.java` 三段式 stty -echo → 单行钩子代码 → stty echo，消除安装代码回显与 readline `>` 续行噪声；回归 `installSilencesPtyEchoAroundIntegrationCode` / `integrationCodeIsSingleLine`（ShellIntegrationTest）；需求回写 `specs/ssh-connection/spec.md` “终端集成静默安装”，坑回写 known-issues #14。
- [x] 17.2 断线重连（用户反馈“moberXterm 按 r 重连，finalShell 有重连按钮，目前断线后没有重连功能”）：`F/components/terminal/TerminalTimeline.vue` 断线态拦截 r/R 键 emit reconnect；`F/views/WorkspaceView.vue` 新增 reconnectWorkspace 双路径 + 工具栏“重连”按钮；closed/WS onclose 两条终态路径清空失效 sessionId（消除死会话错误风暴）并写重连指引；会话 id 改为恒更新使重连新会话被采纳；不做自动重连（会话重建丢 cwd，上下文切换须用户显式确认）；回归：TerminalTimeline.spec 拦截 4 用例 + WorkspaceView.spec 重连 4 用例；需求回写 `specs/terminal-workspace/spec.md` “断线重连”，坑回写 known-issues #15。
- [x] 17.3 工作区导航与连接复用（用户反馈“点击连接后……切换其他页面没法再切回有 tab 的 workspace 页，会造成多个 tab”）：服务器列表“连接”改为进入语义（复用该主机最后创建 tab，不新建实例不重复建连）；侧栏新增“工作区”入口回跳最近活跃 tab（store 记录 lastActive，关闭时回退）；无 tab 不显示入口；回归：workspaces.spec / ServerListView.spec / WorkspaceView.spec / App.spec 导航 RED→GREEN 四向全绿；需求回写 `specs/terminal-workspace/spec.md` “每个连接实例独立且入口不重复建 tab”与“工作区导航回跳”。
- [x] 17.4 切页保连接保历史（浏览器终验发现：cd 后切设置页再回跳，终端空白且会话重建）：`F/App.vue` router-view 改 v-slot + `KeepAlive :include="['WorkspaceView']"`；`F/views/WorkspaceView.vue` 加 `defineOptions({ name: 'WorkspaceView' })` 使实例不被卸载，`onActivated` 对活动 tab 调 refit 恢复尺寸；回归：App.spec KeepAlive 用例（RouterViewStub 经 global.components 注册）+ WorkspaceView.spec name 断言，定向 21/21 绿；坑回写 known-issues #16，行为语义由 17.3 的“工作区导航回跳”/“后台连接继续工作”场景覆盖。
- [x] 17.5 Agent 会话当前目录感知（浏览器终验发现：cd /tmp/acceptance 后问“列出当前目录文件”，AI 答“当前目录 /”，日志铁证 `list_dir: path=/`）：`B/ssh/PtyCommandScheduler.java` 加 volatile sessionCwd，handleCwd 无条件更新（人工 cd 的 cmdId=0 帧不再丢弃）+ getter；`B/ai/AgentTools.java` 新增 sessionCwdOf 经 findScheduler 查找链；`B/ai/AgentSystemPrompt.java` 4 参重载注入工作目录（未知不渲染），3 参委托保持兼容；`B/ai/AiAgentService.java` 存 agentTools 字段，runTurn 与上下文恢复重建两处都注入；回归：manualCwdFrameUpdatesSessionCwd / promptInjectsSessionCwdWhenKnown / promptOmitsCwdSectionWhenUnknown / sessionCwdOfRoutesToTheSessionScheduler，定向 95/95 绿；需求回写 `specs/ai-agent/spec.md` “会话当前工作目录感知”，坑回写 known-issues #17。
- [x] 17.6 导航回跳 tab 偏差修复（浏览器终验发现：ws-2 活跃时切设置页再点侧栏“工作区”回跳到 ws-1）：根因是 #16 KeepAlive 次生问题——缓存的 WorkspaceView 内 watch(effectiveActiveId) 不随离开路由而停，路由参数变空时回退值（首个 tab）被当作真实活跃 tab 登记污染 lastActiveId；修复：登记守卫 `if (id && routeWorkspaceId.value)`；回归：WorkspaceView.spec「离开 workspace 路由不得覆盖 lastActiveId」（vue-router mock 改共享 reactive route）+ 浏览器双向复验，前端 264/264 绿；坑回写 known-issues #18。
- [x] 17.7 首连双提示符修复（用户实测反馈：首次连接同一行出现两个 `[root@localhost ~]#`，后续正常）：真根因（浏览器 xterm buffer 取证实证）是 `ShellIntegration.install()` 旧三段式分次发送——钩子 code 执行完弹首帧开闸+prompt ①，随后的 `stty echo` 又是一条命令再弹 prompt ②；修复：合并为单条命令行 `stty -echo; 钩子; stty echo\n` 一次性发送，整行只触发一次 PROMPT_COMMAND；回归 `ShellIntegrationTest.installSendsHooksAsSingleCommandLine`（hasSize(1)+单行断言），定向 78/78 绿。附带加固（第一层假设虽非双 prompt 成因，但竞态窗口真实存在）：`B/ssh/PreInstallMuteListener.java`（吞 stdout/stderr、透传 onClosed）在 bash 会话作为 relay 初始监听器把保护起点提前到第一个字节，封死登录 banner/首 prompt 抢在闸门接入前泄漏；`installShellIntegration` catch 补 switchTo 兜底防永久静音；回归 PreInstallMuteListenerTest 2 用例 + SshTerminalServiceTest banner 集成 2 用例（FakeSshServer 新增可注入 loginBanner）；需求回写 `specs/ssh-connection/spec.md` “终端集成静默安装”保护起点约束，坑回写 known-issues #19。
- [x] 17.8 单回合工具调用轮次上限调高（用户反馈：最大 8 步太低，允许 30 步）：`B/ai/AiAgentService.java` `MAX_TOOL_ROUNDS` 8→30，触顶说明文案/测试断言均由常量联动；回写 design.md D7 与 `specs/ai-agent/spec.md` 新 Requirement “单回合工具调用轮次上限”。
- [x] 17.9 连接入口撤销复用、每次新建独立 tab（用户修订：同一服务器每次连接都应是独立 tab，Agent/人工审批互不影响；推翻 17.3 的“进入复用”语义）：`F/views/ServerListView.vue` `connectWorkspace` 去掉“已有 tab 则跳转”分支，无条件 `createWorkspace`+跳转；跨页回到工作区的诉求仍由侧栏回跳入口承担；回归：ServerListView.spec 两复用用例改写为“每次新建独立 tab”断言（RED→GREEN 27/27）；需求回写 `specs/terminal-workspace/spec.md` “每个连接实例独立且连接入口每次新建”。
- [x] 17.10 Agent 模式 Ctrl+C 打断在飞回合（用户反馈：对话中要能像 Shell 一样 Ctrl+C 打断）：三层断链全部接通——①契约 `contract/asyncapi.yaml` AiStreamType 新增上行 `stop_turn`；②后端 `B/ws/AiStreamFrame.java` 枚举末尾加 `STOP_TURN` + `B/ws/AiWebSocketHandler.java` `handleStopTurn`（缺 conversation_id 忽略；命中 `AiAgentService.stop` 中断 worker→final+停止注记；未命中静默——停止是幂等通知），激活此前死代码 `stop()`；并接通第四层断链（异常包装层，浏览器实测新暴露）：`B/ai/AiAgentService.java` `runTurn` 的 RuntimeException 分支顶部加 `causedByInterrupt` cause 链识别——langchain4j 阻塞流读把 InterruptedException 包成 ReactiveException，不识则 Ctrl+C 误报 `model_endpoint_error`，识则走停止注记；③前端 `F/types/ws-messages.ts` `AiStreamType.StopTurn`、`F/components/terminal/TerminalTimeline.vue` 新增 `generating` prop（生成态 Ctrl+C 写 `^C` 留痕+emit `agentStop`）、`F/views/WorkspaceView.vue` `stopAgentTurn` 经本 tab AI 通道发帧；并接通第五层断链（中断标志残留层，run9 实测再暴露）：reactor 抛包装异常时恢复线程中断标志，而收尾帧的 Tomcat WS blocking send 跑在同一 worker 线程——标志残留让第一帧发送即失败（连接 1006），停止注记永远发不出；修复：后端两处 catch 收尾前 `Thread.interrupted()` 清标志（取代反模式的恢复标志写法，DB 落库必成、帧发送尽力而为），前端改为发帧后立即本地闭环（清生成态+写停止注记行，丢帧不可接受、双份注记可接受、后端送达幂等兼容）。回归：AiWebSocketHandlerTest 4 新建 + 定向 45/45；AiAgentServiceTest 新用例 interruptWrapped…StopNoteNotError / stopCleanupRunsOnInterruptFreeThread（后者首版断言写在 finally 后自擦证据——假绿，修正为 try 内捕获 leaked）（RED→GREEN 30/30）；前端三 spec RED→GREEN + WorkspaceView 本地闭环用例；需求回写 `specs/ai-agent/spec.md`「受控停止任务」Ctrl+C Scenario（本地闭环语义）；坑回写 known-issues #20（五层全记）。

