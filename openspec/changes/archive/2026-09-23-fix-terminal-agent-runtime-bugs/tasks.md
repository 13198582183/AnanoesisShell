# Tasks: 修复终端与 Agent 运行时三 BUG

> 本变更走"先实证修复、后补全工件"路径：任务在 TDD 循环中已全部完成，勾选附验证证据（记录于 `.tmp-be-fullreg-b.log`、前端 vitest 输出与浏览器验收会话）。

## 1. BUG-A：PTY 命令空闲超时 + 绝对上限（command-approval）

- [x] 1.1 RED：`PtyCommandSchedulerTest` 新增用例——持续输出超配置时长不得被中断、静默达时限必须被中断、触绝对上限无输出也中断、`ptyWaitCeilingSeconds` 恒大于设置值（首跑确认失败）
- [x] 1.2 GREEN：`PtyCommandScheduler` watchdog 改为按 `min(timeout-idle, maxAbs-elapsed)` 续排 + 20ms 防自旋，`lastActivityNanos` 由 collectOutput/onFrame 刷新；新增 `DEFAULT_MAX_ABSOLUTE_MS=30min` 与静态 `ptyWaitCeilingSeconds`（定向 27/27 通过，XML 报告 tests=27 failures=0）
- [x] 1.3 GREEN：`ApprovedCommandRunner.tryPtyPath` 与 `AgentTools.tryPtyPath` 的 `future.get` 改接 `ptyWaitCeilingSeconds(...)` 并注释 WHY（内层先断外层晚断，防误回落 exec 重跑）（随 1.2 定向与全量回归验证）

## 2. BUG-B：停止链路穿透（ai-agent）

- [x] 2.1 RED：`AiAgentServiceTest` 新增 3 用例——只读工具期间停止不回退且不回喂 TOOL_RESULT、审批命令期间停止不回退、stop 命中在飞命令时调用 `scheduler.interruptCurrent()`（首跑确认稳定 RED；断言选"必然可观测痕迹"，见 design D4）
- [x] 2.2 GREEN：新建 `support/TurnCancelledException`；`ApprovedCommandRunner` / `AgentTools.tryPtyPath` 的 `catch (InterruptedException)` 由 `return null` 改抛 TurnCancelled；`AgentTools.executeOrReturnError` 在 `catch (RuntimeException)` 前 rethrow TurnCancelled（杜绝 tool_result(ERROR) 伪装）（编译 + 定向通过）
- [x] 2.3 GREEN：`AiAgentService` 引入 `stopRequested` 权威标志（stop 置位/submit finally 清除）与三检查点（轮首/工具间/流式 chunk）；`runReadOnly` 对包装异常 `causedByInterrupt` 识别重抛（定向 108/108 通过）
- [x] 2.4 GREEN：`runTurn` 登记 `inFlightSession`（finally 移除），`stop()` 经 `AgentTools.interruptInFlightCommand` → `PtyCommandGateway.findScheduler().interruptCurrent()` 打断远端在飞命令（用例 3 验证 verify(scheduler).interruptCurrent()）

## 3. BUG-C：首连窗口尺寸同步（ssh-connection）

- [x] 3.1 RED：前端尺寸同步用例 4 失败确认（首连/采纳会话必须发出 resize 帧、隐藏实例不发零尺寸）
- [x] 3.2 GREEN：`syncSize(force)` 支持强制发送；ResizeObserver 观察容器；终端实例挂载/采纳会话 refit 后补发一次真实行列（定向 + 前端全量 273/273、vue-tsc 0 错误通过）

## 4. 回归与验收

- [x] 4.1 后端全量回归：`mvnw test` 767/767 BUILD SUCCESS（final 系列最后一跑）
- [x] 4.2 前端全量回归：vitest 273/273 + vue-tsc 0 错误 + vite build 成功
- [x] 4.3 浏览器端到端终验（真实测试机 CentOS）：BUG-A——80-tick 循环命令超 60s 完整跑完、final 总结含 tick-80；BUG-B——300-tick 循环执行中 Ctrl+C → stop_turn 上行 → 远端 ^C 输出截断 → 停止注记 → 5s 稳定无续输出、无 tool_result 错误回喂；BUG-C——新连接 resize 97x22 帧发出、远端 stty 与本地一致、方向键调历史渲染正常

## 5. 文档与流程

- [x] 5.1 `.qoder/known-issues.md` 回写 #21（空闲超时语义）/#22（停止被吞回落）/#23（winsize 未同步）三完整条目（症状/根因/方案/预防）
- [x] 5.2 本变更工件（proposal / delta specs ×3 / design / tasks）创建并通过 `openspec validate --strict`
- [x] 5.3 归档变更：delta specs 同步主 specs（command-approval / ai-agent / ssh-connection，MODIFIED 块已整体替换并复验 validate 通过）
- [x] 5.4 三仓提交闭环：backend（jacoco 门禁 + 三 BUG 修复两笔）、frontend（BUG-C 尺寸同步）commit+push → 主仓库记录子模块指针 + openspec/known-issues 提交推送
