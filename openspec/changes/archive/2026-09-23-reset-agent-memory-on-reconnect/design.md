# Design: reset-agent-memory-on-reconnect

## 决策

### D1：重置点选在前端 `reconnectWorkspace`，而非后端会话生命周期
- Agent 记忆的载体是 tab 绑定的 `conversationId`（后端按它加载历史回喂），前端换新 id 即天然清零，**后端零改动**。
- `reconnectWorkspace` 是 r 键与重连按钮的**唯一汇聚点**，且已有终态守卫（仅 closed/failed 可进入）——语义精确命中"用户显式重连"，不会误伤首连（首连 conversationId 本就是 null，`if (ws.conversationId)` 守卫跳过、不写注记）。
- 否决项"后端在新 PTY 会话建立时使旧 conversation 失效"：conversation 与终端会话在数据模型上是弱关联（conversation 绑 host 不绑 session），强行绑定会破坏"纯问答回合不依赖终端"的既有能力，且影响面跨库表语义。

### D2：解绑而非删除
旧 conversation 及消息完整留在库中（历史面板可查、审计不丢），仅 `ws.conversationId = null` 使本 tab 不再引用——与既有"历史保留"约束（关闭/停止流程 MUST 保留历史）一致。

### D3：连带解除流式锁（防自造卡死）
解绑后旧对话在飞回合的 final/error 帧会被 `handleAiStream` 的 conversation 归属过滤（`!ws.conversationId → return`）丢弃，`aiStreamingByWs` 将永卡 true、该 tab 输入永久阻塞。故重置块内同步 `aiStreamingByWs[wsId] = false`——重连本就意味着放弃死会话上的在飞回合。

### D4：conversationId 持久化白名单保留
跨 F5 刷新延续对话是既有刻意设计（刷新非"重连"语义，用户预期连续）；刷新后 WorkspaceView 重挂载会走首连路径（非 reconnectWorkspace），不触发重置。两类时机语义不同，不合并。

### D5：重置前先经 stop_turn 终结后端在飞回合（用户实测追加）
初版只解绑前端记忆，用户实测发现重连后新提问仍被后端 `ERR_BUSY`（「本会话正在处理上一条提问」）阻塞：`AiAgentService.inFlight` 是按 conversationId 的内存执行槽，旧回合不自行结束就一直占用；且后端 `afterConnectionClosed` 刻意不取消在飞回合（兼容刷新场景，见 AiWebSocketHandler 注释）。裁决：重连即用户显式放弃旧回合，`reconnectWorkspace` 重置块在解绑前调用既有 `stopAgentTurn(wsId)` 发 `stop_turn` 上行，复用 Ctrl+C 停止链路（后端 interrupt + 审批失效 + 终止命令执行 + 释放 inFlight）；AI 通道断开时 stopAgentTurn 内部 no-op，解绑与流式锁复位仍作为兜底。后端零改动。

### D6：重连连带重建 AI/审批通道（浏览器终验追加）
后端重启模拟断线终验时发现：三条 WS 通道（/terminal、/ai、/approval）同生共死，但 `WsChannel` 无自动重连，旧 `reconnectWorkspace` 只拉起终端通道——重连后 Agent 提问被 `sendAiMessage` 的「AI 通道未连接」分支 console.warn 静默丢弃，新会话实际仍不可用。修复：重连末尾无条件 `rt.aiChannel.connect()` + `rt.approvalChannel.connect()`（`connect()` 对已连接通道幂等早返，重复调用安全）。后端重启场景下 inFlight 随进程清空，D5 的 stop_turn 在通道断开时 no-op 不构成矛盾；网络抖动场景通道未死、stop_turn 正常送达。

### D7：通道断开时 stop_turn 延迟补发（用户真实路径复现追加）
按用户澄清的真实路径（Agent 执行 nodejs 限速下载 → 下载中途 Ctrl+C → 断开连接 → 重连同一窗口）复现时发现 D5 的时序缺口：整条 WS 断开（网络抖动/vite 重启）后点击重连的瞬间，aiChannel 仍是 disconnected，`stopAgentTurn` 的通道守卫使其 no-op——旧回合永不打断、继续占用 inFlight；后端重启终验测不出此缺口（inFlight 随进程消失）。修复：重置块按通道状态分流——已连接直接 `stopAgentTurn`；断开则挂一次性 `onStateChange` 回调，AI 通道恢复 connected 后补发 `stop_turn(staleConvId)`（解绑前捕获旧 id 入闭包）。补发是幂等通知：后端未命中在飞回合无副作用；通道在补发前瞬间又断则 catch 静默，旧回合随连接自然清算。

## 测试

RED→GREEN：
- `WorkspaceView.spec.ts`：①重连后 conversationId=null + 终端写入含"Agent…重置"注记；②首连（无旧对话）不写重置注记（防噪音回归）；③重连时解绑前先发 `stop_turn` 上行打断旧在飞回合（D5）；④重连连带重建 AI/审批通道（D6）；⑤整条 WS 断开后重连：stop_turn 延迟到 AI 通道恢复连接后仍送达旧对话（D7）。
- `workspaces.spec.ts`：`setConversationId(id, null)` 解绑（类型放宽的编译级 + 行为断言）。
- 全量：前端 279/279、`vue-tsc --noEmit` 干净。
- 浏览器终验（用户真实路径）：Agent 执行 nodejs 限速下载 → 下载中途 Ctrl+C 强制打断（^C 留痕 + 停止注记）→ 断开连接（整条 WS 断，SPA 状态保留）→ 点「重连」→ 三通道重建、重置注记出现、conversationId 置 null → 新提问在新对话畅通（无 ERR_BUSY、审批与回复完整）。
