# Design: cancel-ends-turn-auto-prompt

## 决策

### D1：用户取消 = 回合终结信号，而非可回喂的工具结果
`routeAndReport` 的审批分支现在把取消与超时统一折叠为 `ToolOutcome(REJECTED)` 回喂模型（loopRounds 下一轮模型收到「用户已拒绝」继续推理）。改为：`ToolOutcome` 增加 `userRejected` 标记（仅用户点击取消置真），loopRounds 在落完 tool 消息后检测任一步 `userRejected` → 不再拼 prompt 回喂，直接 `finishWithNote(conversationId, CANCEL_END_NOTE, "approval_cancelled", ...)` 收场（answer_delta 注记 + 落库 + finished 帧，复用轮次上限的收场模式）。本轮已流出的 answer/thinking 早已增量落库，天然满足"只回复本次对话内的内容"。

### D2：超时不终结回合
审批超时（TIMED_OUT）是"未获得决定"而非用户意愿表达，维持现状回喂模型继续推理——模型可改期再提案或转为向用户提问。与 D1 的区分依据就是 gate 返回的 `ApprovalOutcome`，不新增状态。

### D3：注记文案与停止注记区分
取消终结注记采用后端落库口吻（同 ROUND_LIMIT_NOTE 惯例）：「（已取消本次操作，本轮对话结束。请告诉我下一步。）」——与 STOPPED_NOTE（用户主动停止）语义不同，前者等待新指令的指向更明确。前端无需识别文案：终结走标准 finished 帧，既有流处理自动复位生成态。

### D4：提示符自动落位收口在前端组件层
`TerminalTimeline` 新增并 expose `openAgentPrompt()`：Agent 模式下若提示符未打开则写 `'\r\n' + AGENT_PROMPT` 并置 `agentPromptOpen = true`。`WorkspaceView` 在回合结束四类触点调用：①AI 流 `Final` 帧（覆盖回答完成/取消终结/轮次上限——后端全部走 finished 帧）；②`Error` 帧；③`stopAgentTurn` 本地闭环（不等后端帧）；④重连重置注记后（同属"等待输入"时刻）。触发时仅当 `ws.mode === 'agent'`，Shell 模式不打扰 PTY 提示符。

### D5：异步输出与空提示行的防拼接
自动落位的 `❯` 可能被晚到的 PTY 输出拼在同一行（惰性补打当初正是为此）。对策：`writeToTerminal` 写入口检测 `agentPromptOpen && agentDraft === ''` 时先写 `'\r\x1b[K'` 清掉空提示行并复位 `agentPromptOpen = false`，再写输出——与既有 initialPromptWritten 占位行清除同构；用户随后键入时 `ensureAgentPromptLine` 惰性补打兜底，输入行永远以 `❯` 开头独占新行。

## 测试

RED→GREEN：
- 后端 `AiAgentApprovalTest`：用户取消（gate.respond CANCEL）后断言——出现 `approval_cancelled` finished 帧、模型脚本若无第二轮响应则不再被调用（ScriptedChatModel 耗尽即抛可证）、无后续 tool_call 帧、拒绝步骤仍落库。
- 前端 `TerminalTimeline.spec.ts`：`openAgentPrompt()` 写入 `❯`；空提示行遇 `writeToTerminal` 输出时先清行（断言写入序列含 `\x1b[K`）。
- 前端 `WorkspaceView.spec.ts`：Agent 模式收到 Final/Error 帧后调用 `openAgentPrompt`；Shell 模式不调用。
- 全量：后端 `mvn test`、前端 `vitest run` + `vue-tsc --noEmit`。
- 浏览器终验：Agent 提问触发下载审批 → 点「取消」→ AI 不再发起新回合（无新思考流/审批卡）+ 注记出现 + `❯` 自动落位；正常回答完成后 `❯` 自动出现、直接键入可发起新问题。
