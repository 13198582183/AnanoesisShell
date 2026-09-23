# Proposal: fix-manual-busy-deadlock

## Why

用户报告（BUG-D，附截图与后端日志铁证）：**停止 Agent 回合后再让 Agent 执行，模型无限重复之前的思考、就是不执行**。

根因是 `PtyCommandScheduler` 的 MANUAL_BUSY 结构性死锁闭环：

1. 用户在终端敲过任意键（哪怕只是半行未回车）→ 每个 WS input 帧把状态标为 `MANUAL_BUSY`；
2. `MANUAL_BUSY` 的**唯一**恢复证据是 PROMPT 帧，而 PROMPT 只在有命令真正执行完毕时出现；
3. 但 `submitCommand` 在 `MANUAL_BUSY` 下**直接拒绝**Agent 获准命令（"当前状态 MANUAL_BUSY 不接受命令提交"）→ 不发命令 → 永远等不到 PROMPT → **永久 busy**；
4. 被拒命令以 tool_result 失败回喂模型 → 模型换个姿势重提同一命令 → 再被拒 → 表现为"重复思考不执行"。

日志铁证（be-start.log 16:46:48–16:46:59）：curl nodejs 安装命令获准后被拒 → approval updateById failed → round=2 模型再提相同命令 → 再拒 → 用户被迫停止回合。

## What Changes

- **busy 自愈过期**：最后一次人工按键后静默超过时限（默认 10 秒，连续按键重置计时）且无前台命令在跑（无 CMD_START 证据）→ 发 Ctrl-C 清除疑似残留半行（参照现行 ssh 客户端注入前清行）→ 回 `MANUAL_IDLE` 并派发排队命令，打破死锁。
- **busy 期间提交语义变更**：`submitCommand` 在 `MANUAL_BUSY` 下从"拒绝"改为"排队"，自愈/恢复后自动派发（**破坏性语义变更**：依赖"busy 拒绝提交"旧行为的调用方与测试需同步更新）。
- **前台程序保护**：busy 期间收到 CMD_START（用户前台命令/全屏程序在跑）→ 取消自愈任务，防止 Ctrl-C 误杀 top/vim/嵌套 Shell；恢复仍走 PROMPT 链路。
- **恢复路径统一取消自愈任务**：PROMPT 恢复、显式 `onManualIdle`、`onStopping` 均取消待触发的清行任务，不补发多余 Ctrl-C。
- **spec 修订**：修订 `terminal-workspace`「持久执行环境与输入所有权」中"不凭静默时间猜测命令完成"的绝对化表述——其本意是防"猜命令已结束"，但旧措辞把"busy 状态的静默自愈"也一并禁掉了，正是死锁的设计源头；新措辞区分两者。

## Capabilities

### Modified Capabilities

- `terminal-workspace`：「持久执行环境与输入所有权」需求修订——busy 排队语义、静默自愈清行、前台命令保护三条新行为契约（含 2 个新场景，既有场景名全部保留）。

### Unchanged Capabilities

- `ssh-connection` / `command-approval` / `ai-agent`：帧协议、审批链路、回合停止链路本身不变；自愈完全收敛在调度器状态机内部。

## Impact

- **代码**：`backend/…/ssh/PtyCommandScheduler.java`（新增 `DEFAULT_BUSY_EXPIRE_MS`、7 参构造器、`scheduleBusyExpire`/`cancelBusyExpire`/`onBusyExpired`；`onManualBusy`/`onManualIdle`/`onStopping`/`handleCmdStart`/`handlePrompt`/`submitCommand` 六处行为挂接）。
- **测试**：`PtyCommandSchedulerTest` 新增 ManualBusySelfHeal 嵌套 5 用例；旧用例 `manualBusyBlocksAgentSubmit`（断言拒绝）改为 `manualBusyQueuesAgentSubmit`（断言排队）；`StateMachine.submitRejectedWhenManualBusy` 删除（unknown/stopping 拒绝用例已覆盖残余语义）。
- **协议 / DB / 前端**：无变更（纯后端调度器状态机修复）。
- **兼容性**：获准命令不再被 busy 卡死是修复目标；10 秒自愈时限可能让用户在半行输入中途看到排队命令注入（前被 Ctrl-C 清行），与现行成熟 ssh 客户端行为一致，属可接受权衡。
