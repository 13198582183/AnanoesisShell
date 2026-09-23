# 多连接统一智能终端与 SFTP 技术设计

## Context

动机与范围见 proposal.md。当前 `TerminalView.vue` 同时管理路由、PTY、聊天和历史，卸载即释放通道；后端 PTY 与 AI exec 分离。`AiAgentService` 在回合开始全量读历史再截 60 条，工具循环继续向请求追加；`sanitize` 只校验相邻消息，不检查所有调用标识。模型 provider 名称还影响私有思考字段。SFTP 尚无业务入口。

本设计替换上述限制，不更换现有技术栈。所有路径均相对仓库根；文中新增文件、接口和字段是后续 apply 的实施目标，并非已经实现。当前仅生成规划工件。

## Goals / Non-Goals

**Goals:**
- 同主机可多开，每个连接独立且可验证归属；同一连接内真实共享 Shell 状态。
- 操作时间线、内嵌审批、历史、上下文预算与 SFTP 均具有明确的资源及失败边界。
- 每个模块有独立测试入口；先验证终端集成，再推进契约、后端和前端，不以 UI 演示代替执行正确性。

**Non-Goals:**
- 不用独立 exec 冒充持久 Shell；不把 SFTP 内容自动交给 AI；不加入长期摘要记忆、向量检索、厂商专属会话 API。
- 不自动恢复远端进程，不保证网络失联时命令回滚，不承诺恰好一次远端副作用。
- 不实现桌面壳、目录递归、断点续传、远程编辑或备份版本产品。既有凭据和主机指纹的发布安全欠账不在此处宣称解决。

## Decisions

### D1. 连接实例是运行时隔离边界

- `session_id` 是每次连接生成的 UUID，不按 `host_id` 复用。前端 tab 使用该标识，连接建立前使用仅本地的临时标识，失败后保留可重试的失败 tab。
- `SessionRuntime` 持有一个 SSH 传输连接、一个持久 PTY、输入调度器、SFTP 子通道及当前活动对话；同主机多个 runtime 完全独立。
- `conversation_id` 不可变地绑定一个 session；同一 session 可有多段历史，但只允许一个活动 `run_id`。新连接创建新对话，不自动选择全局最近历史。
- 旧版无 session 的对话与已关闭 session 的对话只读。历史入口按主机/连接查看、删除；不提供将旧对话执行权自动搬到新 PTY 的隐式行为。
- 单个控制端失联后保留 runtime 30 秒供重订阅；超过宽限期则停止任务、清算传输并关闭连接。显式关闭立即进入清算。其他视图切换不注销订阅，浏览器刷新不承诺恢复连接。
- 不采用仅给 router-view 加 key 的方案：它会在切换时销毁资源。使用应用级 workspace store + runtime 注册表，路由只选择工作区；runtime 在显式关闭/失联清算时销毁。

### D2. 控制能力与定向事件

- `POST /api/sessions` 创建连接，返回会话信息与仅一次展示的 256-bit `control_token`。服务端仅存其散列于 runtime，前端只保留内存，不写 URL、日志、localStorage 或数据库。
- 连接级 REST 使用 `X-Session-Control`；WS 在连接后首帧提交 `bind(session_id, control_token)`，验证后才可订阅/发送，10 秒未绑定即关闭。浏览器请求校验允许的 Origin/同源策略；有 JSON 请求体的控制端点要求 JSON 内容类型，原始上传 PUT 要求 `application/octet-stream`，无请求体的 GET/DELETE 不强制 JSON。下载 GET 按 D9 独立验证票据。这不是完整多用户登录系统，也不替代后续本地服务安全发布门禁。
- 创建/选择活动对话、提交 Agent 请求、执行、订阅和传输属于连接控制面，必须检查实体归属及连接凭证。历史列表、消息查询、删除和审计查询沿用现有应用级管理接口边界，不要求已经销毁的 runtime 凭证，仍须校验输入与删除冲突；查询或删除历史绝不授予执行权。当前没有完整应用身份认证，不将该边界描述为多用户隔离，也不把服务直接暴露到公网。
- 终端、AI、审批事件都带 `session_id`；任务带 `conversation_id/run_id`，工具带 `call_id/command_id`，审批带 `approval_id/version`。由服务端验证实体链和控制能力，不接受请求体 host 覆盖绑定。
- runtime 内事件有单调 `event_seq`；订阅恢复返回当前快照和可用的有界事件尾部，缓冲默认 1 MiB。缺口明确显示输出可能缺失，不伪造完整终端恢复。审批快照独立可恢复，不能依赖事件尾部恰好包含请求。
- 短时下载票据只授权一个 transfer，不能当作通用连接凭证，见 D9。

### D3. 真实共享 PTY 与 Shell 集成

- 所有 Agent 远端工具通过所属 runtime 的同一持久 Shell 执行；SFTP 是同一 SSH 连接上的独立 subsystem，不占用 Shell 输入。
- 第一阶段明确支持 Linux Bash 4+ 的会话级集成；不改用户 `.bashrc` 等永久文件。不支持或无法安全安装集成的 Shell 保留人工终端/SFTP，但禁用自动工具并说明原因。不得自动换壳或悄悄使用 exec；扩展其他 Shell 是后续兼容工作。
- 在现有交互 Shell 中安装会话级 preexec/prompt 集成：记录命令开始、命令结束、退出码、目录和当前 Shell 身份。结束钩子先保存 `$?`，避免后续处理改变真实退出码；保留已有提示配置，不能覆盖无法兼容的 DEBUG/PROMPT_COMMAND 钩子后假装成功。
- 控制帧使用有长度限制的 OSC 消息，包含会话随机 nonce、命令标识及编码后的目录；流式解析器处理分片、多帧、非法长度与 UTF-8 边界，并从终端显示流中剥离内部帧。nonce 只减少误识别，不认证恶意服务器；远端输出始终不可信。
- 输入状态为 `manual_idle/manual_busy/agent_owned/stopping/unknown`。人工输入过半行、粘贴或全屏/嵌套 Shell 时不得注入；切入 Agent 只改变输入模式，不表示已取得执行权。握手确认处于空提示符后才领取输入权。
- Agent 运行期间拒绝普通人工输入，保留停止/接管与显式中断。自动命令串行执行，读到可靠完成帧才允许下一个；`cd`、`export` 的效果保留于同一 Shell。退出、exec 替换、钩子丢失或中断后没有完成证据均转 unknown，不能用提示符正则/空闲超时猜完成。
- PTY 合并 stdout/stderr；保留现有 60 秒执行超时与 64 KiB 单命令采集上限作为默认配置。超限继续排空、仅丢弃超额采集内容；中断后 3 秒仍无完成证据则标记 unknown，停止自动推进，提示人工检查或重新连接。
- 技术验证必须包含 `cd/export`、多行粘贴、Ctrl-C、vim/top、宽字符、窗口 resize、嵌套 shell、现有提示钩子及标记分片；未通过时停止后续自动执行实现，不把分离 exec 当降级验收。

### D4. 单一终端时间线与输入模式

- `WorkspaceView.vue` 承载 tab 条、当前连接信息、Shell/Agent 模式按钮、可折叠 SFTP 面板；`TerminalTimeline.vue` 把终端输出段与 DOM 分析/审批段置于同一垂直记录流。不存在第二个独立 Agent 聊天页面。
- 采用“已完成终端段 + 一个活动 xterm 段”的呈现结构。只在已确认的命令/提示边界封存展示段；PTY 连接不变，当前终端状态与输入续接，已完成段按可见范围渲染。正常段保留文本选择与 ANSI 颜色；备用屏幕程序期间只使用活动 xterm，不切分、插卡或破坏光标寻址。
- 技术验证先证明展示段切换不损坏终端模式、颜色、提示符和选择复制。实现使用 xterm 的公开接口，不向其内部 canvas 插入 DOM；所需序列化 addon 如确有必要，必须匹配现有 xterm 主版本并在依赖任务中锁定，不引入新的 UI 框架。
- Agent 输入是同一终端底部提示区的模式化输入，自然语言不写入 PTY；Shell 模式继续原始按键转发。模式切换保留各自未提交草稿，不自动提交或清空人工半行命令。
- AI 结果事件只更新卡片状态/引用，实际 PTY 字节只渲染一次。历史视图不实例化可执行终端。后台 tab 保留资源，恢复显示后测量尺寸并发 resize，隐藏 tab 不发送零行列。
- 当前屏幕缓存有界：每连接默认 10,000 行，封存展示段最多 8 MiB；超出后仍可查看已持久的有界命令记录，但不承诺完整终端录制回放。原始屏幕缓存与模型历史不是同一个窗口。
- tab 条、模式切换、内嵌审批和文件操作均可用键盘访问；tab 条使用明确选中态与 roving tabindex，方向键只在 tab 条内导航，不截获 xterm 按键。异步输出不抢焦点，关闭当前 tab 后焦点回到相邻 tab，取消确认后返回触发按钮。分析/进度状态采用节流的 polite 播报，失败与待审批只播报状态摘要，不逐字播报终端流；状态不只依赖颜色，批准前可完整阅读修改后的命令。

### D5. 运行账本、审批与停止

- 新增 `ai_runs`，保存 run、session、conversation、状态、模型配置快照引用、上下文恢复计数及取消代次。新增 `command_executions`，保存来源、run/call、command、输入领取/发送/完成状态、cwd、exit_code、截断标识及有界输出；自动工具的 `(run_id, call_id)` 唯一。
- 每个 session 的操作在同一个串行调度器内裁决。工具提议先持久化 assistant 记录与稳定 call_id，再审批/执行，再保存真实工具结果；SQLite 事务不得跨模型、SSH 或人工等待。
- 执行领取先提交数据库状态，再写 PTY；发生“已领取但写入/落库结果不明”时只标记 unknown，绝不自动重发。此为不重放保护，不声称端到端 exactly-once。
- 内嵌审批维持一条逻辑请求及不可变版本快照。修改产生新版本、旧版本不可执行，保留原到期时间；新版本必须再次点击执行。服务端接受 `expected_version`，不允许按钮自行替换命令参数后沿用旧批准。
- 实际修改后的命令写入工具结果及审计；模型能同时区分原提议和实际执行。批准、拒绝、超时、停止、关闭及领取在同一状态机中互斥，重复操作返回当前状态或 409，不重复执行。
- 停止先改变取消代次并禁止新写入，再取消模型流/待审批、对在途命令发送中断并清算，最后归还安全输入状态。关闭忙碌 tab 必须确认；关闭 SSH 不等于终止所有远端子进程，不能显示“已撤销”。
- 新增记录复用凭据保护与脱敏入口；不得记录控制 token、SSH 登录交互或完整私钥。手工命令/输出是敏感运维数据，界面明确会进入当前会话上下文，剔除终端控制帧与已知秘密，不把任意输出当系统指令。

### D6. 历史存储、人工操作和删除

- 新增 `ai_conversations.session_id`（允许空，引用 sessions）、`ai_messages.source`、`command_id`、`run_id`；不改已有 role CHECK。每条已识别并完成的人工命令作为一条 `role=user, source=shell_event` 的结构化观察记录落库，包含命令、cwd、退出状态及有界结果；不伪造 assistant tool_calls，不保存每次键盘按键。
- 人工记录写入当前连接的活动对话；新建对话后只关联后续操作，不复制旧历史。全屏交互只记录可识别的外层命令结果，不自动抓取密码输入或整段屏幕交给模型。
- 查询列表使用不可变 `(created_at,id)` 倒序 keyset 游标，默认 30、最大 100；按 `host_id/session_id` 筛选。消息使用 `(seq,id)` 倒序读取默认 50、最大 200，页面内按时间正序返回。游标包含筛选值及首屏上界，新增记录不插入当前翻页快照。
- 历史选择使用请求代次，过期响应不更新当前选择；浏览旧历史不切换 runtime 的活动对话或模型事件订阅。当前连接空闲时通过“继续此对话”显式切换自己的活动对话，其他连接及迁移来的无连接历史只读。
- 删除空闲连接的当前活动对话时，在同一调度裁决中将活动引用清空并使旧请求代次失效；界面显示新对话空白状态，不自动调用模型。下一次显式提问或可识别人工命令完成时原子创建新的绑定对话，不能把人工记录写回已删除的标识。
- 单删及批删前锁定目标连接调度/对话状态，拒绝 generating/executing/waiting_approval/stopping 的集合；批量最多 100 个、全成功或全不删。结果已清算为 unknown 的任务历史可删除，但独立审计/执行账本仍保留状态。
- 删除对话级联消息；审批和执行账本的对话/消息外键 SET NULL，并保留目标及最终命令快照。晚到回调校验取消代次及实体仍存在，不得复活已删除消息。
- 不运行自动按条数/日期清理或每次删除后的 VACUUM。删除释放空间供 SQLite 复用，不承诺磁盘文件立即缩小或取证级擦除。

### D7. 60 条窗口与 token 预算

#### 调研结论与选型

- LangChain 官方短期记忆文档将裁剪、删除、摘要、自定义过滤列为常见模式，并要求保留合法工具调用/结果序列。本项目采用裁剪和有界输出，不采用永久删除；摘要作为已比较的方案不在本次实现，避免额外调用、事实漂移及将窗口外历史重新带回。
- OpenAI 官方上下文说明指出输入、输出和推理均消耗窗口；其 token 计数示例明确计数是估算并须考虑 tools。因此不把 60 条或固定字符/4 当可靠容量保证，也不绑定 OpenAI Responses compaction 等非通用接口。
- 资料：`https://docs.langchain.com/oss/python/langchain/short-term-memory`（本轮读取正文的 Common patterns / Trim / Delete / Summarize）；`https://developers.openai.com/api/docs/guides/conversation-state`、`https://developers.openai.com/cookbook/examples/how_to_count_tokens_with_tiktoken`（本轮取得官方搜索摘要，正文抓取返回 403，未假称完整阅读）。这些资料支持方案分类，不作为“使用量排名”的证据。

#### 固定算法

1. 每个 run 开始冻结模型配置；每次模型调用前记录当前最大 seq，执行倒序 `LIMIT 60` 查询并转正序。包括本轮已落库用户、assistant、tool 与人工观察消息；不先读全表。
2. 系统指令与可信当前连接身份/目录单独构建，不占 60 条历史名额，但计入 token；安全约束不能作为可裁剪聊天丢弃。
3. 严格按 call_id 组装 assistant + 全部对应 tool 消息，孤立、重复或缺失组整体排除，不向窗口外补组。当前问题若因异常超长工具循环不在窗口内，明确停止，不偷偷放宽到 61 条或从更早记录重建。
4. 模型配置新增 `context_window_tokens`（默认 8192）、`max_output_tokens`（默认 1024），安全余量 `max(512, ceil(context_window_tokens * 0.10))`。输入预算为容量减输出预留减安全余量；容量要求 1024..2097152，输出为正整数且输入预算至少 512。未知模型显示“保守估算，需按部署校准”，不猜品牌对应容量。
5. 本期不引入 Python tokenizer 或新的 tokenizer 依赖。计数器独立封装：对最终 messages、tools 和结构字段序列化后的 UTF-8 字节数加每消息 32、整请求 256 的结构余量作保守估算；不是对所有兼容模型的数学上界。中文/代码/JSON 按同一实际编码计数，日志只记估算值和数量，不记内容。估算策略可替换，实际超限恢复仍必须存在。
6. 先限制请求投影中的单项工具/人工结果，再从最旧完整组开始淘汰，保留当前问题与本轮最近完整执行结果组。单结果投影最多占输入预算的四分之一，保留头尾各半和截断标识；总量仍超限则继续缩减旧组，不能截断 tool_calls JSON/标识。数据库中已按采集上限保存的内容不被请求裁剪改写。
7. 重新计数完整请求，仍不能放入最小请求则发 `context_budget_exceeded`，提示缩短问题/提高真实容量配置/换模型；不盲发请求、不继续执行工具。每次裁剪以 `context_notice` 提示候选/保留条数与估算，不暴露隐藏指令或凭据。
8. 输出上限写入 Chat Completions 请求；`output_limit_field` 为明确配置的 `max_tokens`（缺省）或 `max_completion_tokens`，只发送一个。推理模型需要的预算由用户按部署配置，不能承诺所有兼容端点的推理计费语义相同。

#### 单次恢复

- `ContextLimitClassifier` 只识别结构化错误码 `context_length_exceeded/context_window_exceeded` 或明确的 token 上限语义，不能把所有 400/413 或“length”结束原因当超限。
- 每个用户 run 共享一次恢复额度。失败调用不进入工具路由，固定该次 history seq 水位和已执行账本，把输入预算降到原值 50%，再次执行同一裁剪流程；最小请求仍放不下则直接失败。
- 新 attempt_id 发出 `attempt_reset`，前端撤回失败尝试的未完成回答，已执行命令段不撤回；不重复用户消息、不重复 assistant 已完成记录、不重跑 tool。第二次失败终止当前 run，终端与原历史保持可用。
- 工具循环上限 8 → 30（用户修订：8 轮频繁拦断真实排障任务，上限只防死循环占住工作线程）；网络错误、认证失败和不支持参数原样明确报错，不在本次增加无限重试。没有执行结果的新工具仅能来自恢复成功后的新有效模型响应，并仍受账本和审批约束。

### D8. 模型供应商表单

- UI 独立维护 selector 与 customProvider：空白仅占位；OpenAI/Ollama 保存 `openai/ollama`；其他保存 trim 后非空自定义字符串。旧未知名称回填其他；不把 `other` 当持久协议值，不强制小写用户自定义名称。
- 三种来源均走现有 Chat Completions 路径装配，保留 base URL 归一化；不创建 MindIE 探针、ReAct 或 Ollama 原生 adapter。
- 新增 `thinking_request_format=none|qwen_compatible`，新配置默认 none；qwen_compatible 明确发送现有两组思考开关。迁移既有 openai 配置为 none，其他既有值为 qwen_compatible，以保持旧请求行为并让用户可见修改；不在“其他”名称上继续隐式分流。
- 本期保留现有 API key 新建必填和编辑留空不变更语义；Ollama 选项表示兼容端点预设，不等于新增免认证模式。界面说明无鉴权服务仍需提供其兼容客户端接受的非敏感占位值；未来真正可选认证需另改契约，不能自动伪造用户密钥。

### D9. SFTP 双向传输

#### 通道与接口

- 每个运行中任务独占一个 SFTP 子通道，复用所属 SSH transport，不复用 PTY 输入。`SftpService` 负责路径/元数据，`TransferService` 负责状态和流；取消只关闭该任务通道，runtime 关闭才断整个连接。
- `GET /api/sessions/{id}/files?path=&cursor=&limit=` 使用目录 handle 有界 READDIR，每页默认 100、最大 200；不调用全量 ls 再切片。cursor 绑定路径/session/handle，空闲 30 秒释放，每连接最多 2 个浏览 handle；目录并发变化显示“刷新后查看最新”，不承诺远端目录事务快照。
- `POST /api/sessions/{id}/transfers` 创建 `{direction,remote_path,file_name,size,overwrite,expected_target}`；每文件一条记录，返回 transfer_id、status、ready_deadline。状态固定为 `queued → ready → transferring`；上传再进入 `publishing → published`，下载完成为 `delivered`，异常终态为 `failed/cancelled/expired/unknown`。全应用 FIFO 调度，跳过当前 session 已满额的任务；ready 和运行任务合计每 session 最多 2 个、应用最多 4 个，queued 全应用最多 100 个，超限返回 429。排队不占传输 HTTP 流、SFTP 通道或下载票据。
- 前端轮询到 ready 才开始正文请求或领取下载票据；ready 保留配额 30 秒，未领取则 expired 并释放配额，不自动重传。PUT/下载 GET 原子领取 ready 状态，同任务最多一个流；非 ready、重复领取及终态再启动返回 409。阻塞读写放在有界 I/O 执行器，不占用裁决取消的调度线程；取消先改变状态再关闭任务通道，迟到完成回调不得覆盖终态。
- 上传 `PUT /api/transfers/{id}/content` 使用 `application/octet-stream`、XHR/File 直传；服务端固定 64 KiB 缓冲转 SFTP，不经 multipart、Base64、整个 byte[] 或前端 Blob 拼装。默认单文件最大 10 GiB，可配置；实际字节数与声明不符立即失败，零字节文件合法。上传开始 PUT 时才创建临时文件。
- 下载任务 ready 后才允许 `POST /api/transfers/{id}/download-ticket` 获取单次、绑定任务的随机票据，有效期不超过 30 秒且不晚于 ready_deadline。再次领票使旧票据失效，不延长领取期限；服务端仅存散列。使用普通附件导航 `GET /api/transfers/{id}/content?ticket=`，消费票据与领取任务在同一裁决中完成，运行中/终态不得领票或再次下载。票据禁止访问日志、错误日志及 Referrer 泄露；响应 no-store、Referrer-Policy:no-referrer，安全 Content-Disposition 同时给 ASCII fallback 和 UTF-8 filename*，不写入可执行 HTML。
- `GET /api/transfers/{id}` 返回方向、字节、总量、状态与失败码；UI 每秒轮询活动任务。`POST /api/transfers/{id}/cancel` 幂等取消。上传客户端发送进度与远端写入进度分开；下载状态仅到 delivered（服务端发送结束），浏览器落盘由浏览器负责。
- 同源浏览器文件选择与下载适配现有 Web 形态，不依赖 File System Access API，不允许后端根据客户端传入的本地绝对路径读写电脑文件。服务器部署在别处时仍通过 HTTP 将文件送到实际浏览器所在电脑。

#### 覆盖与取消

- 新文件和覆盖都先用同目录随机 `.ananoesis-upload-<transfer_id>.part`，SFTP 独占创建，默认 0600。通过 SFTP WRITE 完成、关闭句柄、核对字节和大小后才发布最终名称；验收用下载后的 SHA-256 比较二进制一致性，不假设服务端具备散列扩展。
- 默认 `overwrite=false`，标准 no-replace rename 碰到新出现目标则冲突，不覆盖。创建时发现既有目标返回 409 和目标快照（类型、大小、mtime），不创建传输任务；前端保留 File 和目标，用户逐项确认后以 expected_target 再次 POST。发布前重新 lstat，检测到变化则以 target_changed 失败并清理本任务临时文件，界面要求重新确认后创建新任务，不自动覆盖或重传。服务端须支持已验证的原子替换能力才能覆盖，否则要求改名，不先删除原文件。复核与 rename 之间不具备 compare-and-swap；覆盖确认明确提示其他进程并发修改仍可能未被检测，原子发布不等于版本条件原子成立。
- 覆盖保留原普通文件的权限位，不擅自放宽权限；权限设置失败时不发布。用户确认覆盖是本次人工传输授权，不借用 AI 审批，也不自动授权其他文件覆盖。
- 发布与取消在 transfer 状态机串行裁决；进入 publishing 前取消可阻止发布，进入后取消只记录请求并等待 rename 结果，不能虚报已取消。已 published 不因取消而删除。失败只清理确认为本任务创建的临时文件；断线无法清理则保留清理待办与可见提示，下次连接提示人工处理，不扫描删除不明远端文件。
- rename 是否已生效但响应丢失时为 unknown，不自动重传/覆盖。客户端断开、磁盘满、权限错误、服务端关闭 subsystem 均结束本任务并释放句柄，不影响 PTY。

#### 路径与限制

- 远端使用 Linux 绝对路径和独立 basename；拒绝 basename 中路径分隔符、`.`/`..`、NUL/CR/LF，不把 Windows 路径当远端目录。远端路径可在用户 SSH 权限内浏览，不假称限制在家目录。
- lstat 校验路径各层与最终文件，符号链接只显示不可跟随，拒绝设备/FIFO/socket 传输。SFTP 协议难以完全消除服务器并发改名/换链竞态，见风险项；不把应用校验宣称为服务端沙箱。
- 下载显示名处理 Windows 保留名、非法字符、尾随点/空格，必要时加安全前后缀；只改本地建议名，不改远端文件。相同本地名称碰撞及保存目录由浏览器处理。
- HTTP/SFTP 使用有界流和背压；进入 transferring 后连续无进度 120 秒失败，不把排队时间或文件总耗时当作停滞时长。原始上传路由明确避开 Spring multipart 默认上限；如存在反向代理，同步配置至少 10 GiB 请求上限、禁请求/响应全量缓冲及足够空闲超时。开发 Vite 代理也加入相关 API 路由验证。

### D10. 契约、数据库与文件职责

- REST：创建/关闭连接控制能力；会话列表/消息游标包装 `{items,next_cursor,has_more}`；单删 `DELETE /api/conversations/{id}`，批删 `POST /api/conversations/batch-delete`；D9 的文件/传输接口；模型预算和思考扩展字段。
- WS：统一协议版本 2，新增 bind、resize、stop、订阅快照、command_started/finished、context_notice、attempt_reset、审批 version/修改/确认回执；新增明确 context、session、transfer 错误码。JSON 控制面生成 REST 接口/DTO/客户端，WS 仍按契约手写并测试，不声称已有 AsyncAPI codegen。
- 二进制 PUT/GET 仍完整定义于 OpenAPI，以独立 `TransferContent` tag 从接口/客户端生成集合排除，仅这两个端点由 `controller/TransferContentController.java` 手写流式适配：PUT 从 servlet 输入流读取，GET 经有界 Spring MVC 异步执行器写响应，不使用默认 Resource 消息转换器整包缓冲。JSON 端点留在生成集合；前端仅二进制正文走 `api/transfer-content.ts` 的 XHR/附件导航，不能调用生成客户端转 Blob。新增契约测试逐项核对这两个路由、媒体类型、鉴权、状态码与响应头，防止例外脱离契约。
- 新 Flyway 迁移 `V2__session_workspace_and_transfers.sql` 增加 conversation/session 绑定、消息来源字段、`ai_runs`、`command_executions`、`approval_revisions`、`file_transfers`，及 approvals 的 run/call/version/最终命令字段。运行账本引用对话使用 SET NULL，审批审计保留目标快照；表状态 CHECK 与 DTO 枚举同时更新。
- 模型配置仍在 settings JSON；通过应用读取旧结构补默认值并在显式迁移步骤写回新字段，不在 SQL 中嵌入凭据或依赖 SQLite JSON 扩展。新增索引覆盖 conversation(created_at,id)、conversation(session_id,created_at,id)、运行活动唯一性及传输(session_id,status)。
- 后端新增职责文件位于 `backend/src/main/java/com/ananoesis/shell/`：`ssh/SessionRuntime.java`、`ssh/ShellIntegration.java`、`ssh/ShellFrameDecoder.java`、`ssh/PtyCommandScheduler.java`；`ai/AgentContextBuilder.java`、`ai/ContextTokenEstimator.java`、`ai/ContextLimitClassifier.java`；`service/AgentRunService.java`、`service/TransferService.java`、`ssh/SftpService.java`。沿既有 controller/entity/mapper 结构增加对应实体和端点。
- 改造既有 `AiAgentService`、`ConversationService`、`ModelConfigService`、`ModelEndpointResolver`、`OpenAiCompatibleChatModelProvider`、`SshTerminalService/Session`、`ApprovalGate`、`ApprovedCommandRunner` 与三个 WS handler。旧 SshExecService 可供既有测试过渡，但新 Agent 路由不得调用它。
- 前端新增 `stores/workspaces.ts`、`runtime/workspace-runtime.ts`、`views/WorkspaceView.vue`、`components/terminal/TerminalTimeline.vue`、`components/terminal/AgentInput.vue`、`components/terminal/InlineApprovalCard.vue`、`components/ConversationHistory.vue`、`components/files/RemoteFilePanel.vue`、`components/files/TransferQueue.vue`。现有 TerminalView 逐步收敛为兼容路由入口，移除生产入口对全局 ApprovalCard 的使用；不在本次规划直接删除旧组件。

## Risks / Trade-offs

- [Bash 集成与分块渲染可能破坏复杂提示、全屏程序或输入边界] → 最先做技术验证；未证明正确则阻塞统一 Agent 执行，不降低到“同屏 exec”验收。
- [任意终端输出、用户命令或模型响应含秘密/恶意指令] → 明确数据来源、保留审批、敏感值遮蔽和有界记录；不声称任意秘密可完全自动识别，既有审计脱敏缺口仍需发布安全评审。
- [token 估算与实际 tokenizer/部署容量不一致] → 保守配置、安全余量、每次调用重预算、一次缩减恢复；不能承诺所有端点永不返回超限，但必须可理解地停止且不重放副作用。
- [连接控制凭证不等于应用身份认证] → 只用于防串线与资源访问；本机服务完整访问控制、known_hosts 仍是另行发布门禁。
- [SFTP 路径/目标在检查后被其他进程改变] → lstat、版本比较、原子发布、未知状态，不承诺协议无法提供的 compare-and-swap；强隔离依赖远端权限和受信服务器。
- [多个 tab/文件持续占资源] → 有界缓存、并发上限、句柄超时、30 秒断线宽限、显式关闭与清算。
- [Windows 7 的浏览器和 JRE 支持有限] → 本期避免必需的新文件系统浏览器 API，但不把 Web 测试当作 Win7/10/11 安装兼容认证。

## Migration Plan

1. 在隔离开发分支完成技术验证和契约版本 2；主库/子仓库分支遵循现有工作流，不在未授权时提交推送。
2. 使用 SQLite 在线备份或完全关闭连接后的完整备份，不能运行中只复制主 db 而遗漏 WAL；保留原凭据保护材料，不输出明文。
3. 应用新 Flyway 迁移，旧 conversations.session_id 为 NULL、历史只读，旧运行连接标记已结束；不搬移历史执行权、不自动删聊天。模型配置补充预算/扩展但保留旧请求行为。
4. 前后端同步切换版本 2；旧客户端收到明确版本错误而非猜测字段兼容。验证单机恢复后再开放新入口。
5. 回退时停止运行中的会话与传输，保留未知执行/临时文件提示，恢复配套程序及备份数据库；不执行破坏性 down migration，不自动撤销远端命令或已上传文件。
6. 验收完成后再按用户指令同步/归档。届时显式修订主 `ssh-connection` Purpose 中“单台”的旧范围描述，以及 rules 中双通道/单工作区等已过时基线；保留旧 MVP 归档及未完成记录作为历史，不重写成曾经完成。当前提案阶段不修改这些文件。
