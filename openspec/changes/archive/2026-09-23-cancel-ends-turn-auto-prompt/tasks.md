# Tasks: cancel-ends-turn-auto-prompt

## 1. RED（失败测试先行）
- [x] 1.1 后端 `AiAgentServiceTest#userCancellationEndsTurnWithoutAnotherModelCall`（实际落点在此类而非 ApprovalTest）：取消 → 断言 `approval_cancelled` finished 帧、模型未被再次调用、终结注记落库（RED 确认：expected 1 but was 2）
- [x] 1.2 前端 `TerminalTimeline.spec.ts`：`openAgentPrompt()` 写入 `❯` 提示符；空提示行遇异步输出先清行再写（RED 确认：not a function ×4）
- [x] 1.3 前端 `WorkspaceView.spec.ts`：Agent 模式 Final/Error 帧后调用 `openAgentPrompt`；Shell 模式不调用（RED 确认：spy 未被调用 ×4）

## 2. GREEN（实现）
- [x] 2.1 后端 `AiAgentService`：`ToolOutcome` 第 5 参重定义为 `userRejected`；`runGated` 仅 CANCELLED 置真（超时/中断保持 false）；`loopRounds` 执行循环遇取消 break、proposals/tool 消息按 outcomes 实际长度截断配对、落库后 `finishWithNote(CANCEL_END_NOTE, "approval_cancelled")` 终结不回喂
- [x] 2.2 前端 `TerminalTimeline.vue`：新增 `openAgentPrompt()` 并 expose；`writeToTerminal` 空提示行防拼接（清行 + 复位 open 态）；`ensureAgentPromptLine` 换行后消费占位行清除标志
- [x] 2.3 前端 `WorkspaceView.vue`：Final/Error 帧、stopAgentTurn 本地闭环、重连重置注记四类触点在 Agent 模式调用 `openAgentPrompt`

## 3. VERIFY
- [x] 3.1 定向：后端 `AiAgentServiceTest` 取消用例 + 前端 TerminalTimeline/WorkspaceView spec 全绿（57/57）
- [x] 3.2 全量：后端 `mvn test` 772/772、前端 `vitest run` 288/288、`vue-tsc --noEmit` 无错
- [x] 3.3 浏览器终验：touch 命令审批卡点「取消」→ 留痕「→ 已拒绝」+ 终结注记 + 无新回合（持续 12s 观察无后续输出、徽章归零）+ `❯` 自动落位；落位行直接键入新问题畅通，回答完成后 `❯` 再次自动落位（无需任何激活按键）

## 4. 收尾
- [x] 4.1 `openspec validate --strict` 通过（变更 + 主 specs 9/9 全绿，含 D7 主 spec 改动复验）
- [x] 4.2 归档变更并同步主 specs（command-approval「用户取消执行」THEN 终结语义、terminal-workspace 新场景「回合结束自动落位输入提示符」已合入，validate --specs 9/9 复验通过）
- [x] 4.3 known-issues 回写（#25 重连时序缺口补发 / #26 取消即终结+惰性提示符空档）+ 三仓提交推送：backend dc9c7bc、frontend 89af530（含 reset-agent-memory-on-reconnect 遗留前端改动）、主仓库 a74a679（含指针）
