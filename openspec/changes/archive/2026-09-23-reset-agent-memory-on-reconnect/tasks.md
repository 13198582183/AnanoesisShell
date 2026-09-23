# Tasks: reset-agent-memory-on-reconnect

## 1. RED（失败测试先行）
- [x] 1.1 `WorkspaceView.spec.ts` 新增用例：重连后 conversationId 清空 + 写边界注记（旧实现未重置，断言 `expected 'conv-old' to be null` 失败确认 RED）
- [x] 1.2 `WorkspaceView.spec.ts` 新增用例：首连（无旧对话）不写重置注记
- [x] 1.3 `workspaces.spec.ts` 新增用例：`setConversationId(id, null)` 解绑（类型放宽前为编译级 RED）
- [x] 1.4 （D5 追加）`WorkspaceView.spec.ts` 新增用例：重连时解绑前先发 `stop_turn` 上行打断旧在飞回合（实现前 `Number of calls: 0` 确认 RED）
- [x] 1.5 （D6 追加）`WorkspaceView.spec.ts` 新增用例：重连连带重建 AI/审批通道（实现前 `connect` 未被调用确认 RED）
- [x] 1.6 （D7 追加）`WorkspaceView.spec.ts` 新增用例：整条 WS 断开后重连，stop_turn 延迟到 AI 通道恢复连接后仍送达旧对话（实现前断开态点重连不发帧确认 RED）

## 2. GREEN（实现）
- [x] 2.1 `stores/workspaces.ts`：`setConversationId` 参数放宽为 `string | null`，补 WHY JSDoc（重连解绑语义、旧记录仍入库）
- [x] 2.2 `WorkspaceView.vue` `reconnectWorkspace`：守卫通过后，若存在旧 conversationId → 解绑置 null + 解除 `aiStreamingByWs` 流式锁 + 写青色重置注记行
- [x] 2.3 （D5 追加）重置块解绑前先调用 `stopAgentTurn(wsId)`：经 AI 通道发 `stop_turn` 终结后端在飞回合（中断模型流/审批失效/终止命令执行/释放 inFlight）
- [x] 2.4 （D6 追加）`reconnectWorkspace` 末尾无条件 `rt.aiChannel.connect()` + `rt.approvalChannel.connect()`：整条 WS 断开后三通道同源拉起，Agent 提问不再被静默丢弃
- [x] 2.5 （D7 追加）重置块按 AI 通道状态分流：已连接直接 `stopAgentTurn`；断开则挂一次性 `onStateChange` 回调，通道 connected 后补发 `stop_turn(staleConvId)`（幂等通知，未命中无副作用）

## 3. VERIFY
- [x] 3.1 定向：`WorkspaceView.spec.ts` + `workspaces.spec.ts` 43/43 通过
- [x] 3.2 前端全量：`vitest run` 279/279（含 D5/D6/D7 新用例）、`vue-tsc --noEmit` 无错误
- [x] 3.3 （D6）浏览器终验：后端重启模拟整条 WS 断开 → 点击重连 → 重置注记出现、localStorage conversationId=null、重连后 AI 通道恢复可发新提问
- [x] 3.4 （D7）用户真实路径浏览器终验：Agent 执行 nodejs 限速下载 → 下载中途（36%）Ctrl+C 强制打断（^C 留痕 + 双停止注记）→ kill 后端模拟断连（SPA 状态保留、「[连接已断开]」+ 重连按钮）→ 重启后端后点「重连」→ 三通道重建、重置注记、conversationId=null → 新提问无 ERR_BUSY、审批与回复完整（pwd → /root）

## 4. 收尾
- [x] 4.1 `openspec validate --strict` 通过
- [x] 4.2 归档变更并同步主 specs（MODIFIED 块合入 terminal-workspace「断线重连」，`openspec validate --specs` 9/9 绿）
- [ ] 4.3 前端提交推送（含主仓库 submodule 指针）
