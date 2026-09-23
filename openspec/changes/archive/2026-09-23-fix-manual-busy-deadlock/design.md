# Design: fix-manual-busy-deadlock

## 背景与根因链（Phase 1 取证结论）

后端日志（be-start.log）+ 代码走读确认的死锁闭环：

```
用户按键（WS input 帧）
  → TerminalWebSocketHandler 每帧调 scheduler.onManualBusy()   [置 busy 的唯一来源]
  → 状态机 MANUAL_IDLE → MANUAL_BUSY
  → 恢复唯一证据 = currentCommand==null 时的 PROMPT 帧          [handlePrompt L497]
  → 但 submitCommand 在 MANUAL_BUSY 下直接 failedFuture 拒绝    [default 分支]
  → Agent 获准命令不发 → PTY 无新输出 → 永无 PROMPT → 永久 busy
  → 拒绝以 tool_result 失败回喂模型 → 模型重复思考重提 → 死循环
```

## 决策

### D1：busy 静默自愈过期（而非"永不等 PROMPT"或"改造帧协议"）
- `DEFAULT_BUSY_EXPIRE_MS = 10_000`：从**最后一次**按键起算（`onManualBusy` 每次重排任务，连续打字/粘贴不被中途打断）。
- 到期任务体 `onBusyExpired`（锁内）：仅当 `state==MANUAL_BUSY && currentCommand==null` 才生效 → 发 Ctrl-C 清疑似半行 → `MANUAL_IDLE` → `tryDispatchNext()`。
- WHY 10 秒：覆盖正常打字停顿又不至于让获准命令等太久；与现行成熟 ssh 客户端"注入前清行"的宽松策略对齐。
- WHY 空提示符上 Ctrl-C 无副作用：bash 仅产生新提示符；有半行则清除——两种情况都不破坏状态。
- 否决项①"input 帧带回车判定半行"：无法覆盖粘贴/退格/方向键等复合编辑，判定成本高且不可靠。
- 否决项②"改造 shell 钩子周期上报提示符"：动帧协议与远端注入脚本，影响面远大于调度器内部自愈。

### D2：busy 期间 submitCommand 排队而非拒绝
- `case MANUAL_BUSY: return enqueueCommand(command)`，与 AGENT_OWNED 排队同链路，自愈/PROMPT 恢复后由 `tryDispatchNext` 派发。
- WHY：拒绝是死锁闭环的一环；排队让"用户停手 → 自动执行"成为默认路径，模型无需重试。

### D3：前台命令保护（CMD_START 取消自愈）
- `handleCmdStart`：`currentCommand==null && state==MANUAL_BUSY`（即用户自己的命令开始跑，如 top/vim/嵌套 Shell/长任务）→ `cancelBusyExpire()`。
- WHY：此时 Ctrl-C 会杀死用户的前台程序，不可接受；恢复重新依赖既有 PROMPT 链路（用户命令结束必产生 PROMPT，无死锁——因为这条路径上命令真的在跑）。

### D4：恢复路径统一取消自愈任务
- PROMPT 恢复（`handlePrompt` busy→idle）、显式 `onManualIdle`、`onStopping` 均 `cancelBusyExpire()`。
- WHY：PROMPT 是比静默超时更强的恢复证据，不取消会在下一次 busy 窗口内误发 Ctrl-C（用例④专测此点：制造新旧窗口差检测未取消的旧任务）。

### D5：注入点约束
- 自愈挂接全部收敛在 `PtyCommandScheduler` 内部；`TerminalWebSocketHandler` 每帧调 `onManualBusy()` 的接线不改（它恰是"最后一次按键"计时信号源）。

## 测试策略（TDD）

RED：ManualBusySelfHeal 嵌套类 5 用例（引用不存在的 7 参构造器 → 编译失败即 RED）：
1. 静默到期 busy→idle；
2. busy 提交排队不拒不发，自愈后 `containsExactly("\u0003", "pwd\n")` 先清行再派发（命令超时拉至 5s 防 watchdog 在 sleep 窗口误中断在飞命令——本轮实测踩坑）；
3. CMD_START 证据下不自愈不清行，CMD_END+PROMPT 才恢复；
4. PROMPT 恢复取消旧任务：busy→PROMPT→sleep(250)→再 busy→sleep(250)，在"旧窗口已过期、新窗口未到"时刻断言仍 busy 且无多余 Ctrl-C（初版 sleep(300) 单次等待会让新任务也到期→假红，已修）；
5. 连续按键重置计时：过期从最后一次按键起算。

旧用例语义更新：`manualBusyBlocksAgentSubmit`→`manualBusyQueuesAgentSubmit`（拒绝→排队）；`StateMachine.submitRejectedWhenManualBusy` 删除（unknown/stopping 拒绝用例已覆盖，曾误改名为重复方法致编译冲突，已清理）。

GREEN 后全量回归 771 用例 0 失败。
