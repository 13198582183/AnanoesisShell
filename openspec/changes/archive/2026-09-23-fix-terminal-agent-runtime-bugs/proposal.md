# Proposal: 修复终端与 Agent 运行时三 BUG（超时误杀 / 停止被吞 / 尺寸未同步）

## Why

浏览器真实验收（用户视角）暴露三个破坏核心使用场景的 BUG：

- **BUG-A**：Agent 执行长时命令（如安装 JDK，实际仍在正常输出）被 60 秒绝对超时误杀——调度器把"超时"实现为"总时长上限"而非"无响应上限"，正常执行中的 yum 被发 Ctrl-C。
- **BUG-B**：Agent 回合在飞时用户无法中途停止——`stop()` 的中断在工具执行/审批回退层被吞成普通失败（伪装成 tool_result(ERROR) 回喂模型），模型"看到失败"后按上一步继续推进，表现为"停不下来"；且远端 PTY 上正在跑的命令不接收任何打断。
- **BUG-C**：切回 Shell 模式按方向键调历史，xterm 渲染全乱——首连后远端 PTY 尺寸停留在默认 80x24，前端从未把真实行列同步过去（本地按 97x22 排版、远端按 80x24 换行，readline 重排越界）。方向键历史是 Shell 基本操作，此 BUG 使 Shell 模式不可用。

三者均已按 TDD（RED→GREEN）修复并通过后端 767/767、前端 273/273 与浏览器端到端实证；本变更按 OpenSpec 流程补齐变更工件并回写 specs（用户约束：所有变更必须经 openspec 变更流程）。

## What Changes

- **PTY 命令调度超时语义修订**：`run_command.timeout.seconds` 从"一次性绝对定时器"改为**空闲超时**（有输出即刷新计时）+ **独立的防跑飞绝对上限**（默认 30 分钟）；等待方（审批执行器 / 只读工具）的 `future.get` 上限与调度器对齐且**晚于**调度器超时（内层先断、外层晚断，消除误回落 exec 重跑）。
- **停止链路穿透**：新增 `TurnCancelledException` 作为"用户停止"显式标记，禁止工具回退/审批回退把它吞成普通失败或回喂 tool_result(ERROR)；`AiAgentService` 引入权威停止标志集合（不依赖线程中断标志）在轮首/工具间/流式增量三处检查点终止回合；`stop()` 经会话映射定位调度器，对在飞远端命令发 Ctrl-C（`interruptCurrent`）。
- **首连窗口尺寸同步**：前端在终端实例创建、会话采纳、容器尺寸变化（ResizeObserver）时机强制 `syncSize` 并向远端 PTY 发送 winsize/resize 帧；隐藏实例不发送零尺寸。

无 **BREAKING** 变更：均为缺陷修复与既有需求语义的精确化，契约字段与 API 形状不变。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `command-approval`：「命令执行的输出约束」需求修订——执行超时的语义从"总时长"改为"无输出空闲时长"，另有绝对上限防跑飞；等待方超时必须晚于调度器自身超时。
- `ai-agent`：「受控停止任务」需求修订——停止 MUST 穿透工具回退/审批回退层（不得伪装成工具失败回喂模型）、MUST 打断远端 PTY 在飞命令、权威停止标志检查点语义。
- `ssh-connection`：「远端终端尺寸同步」需求修订——补充首次连接建立后 MUST 完成一次真实行列同步（不依赖窗口缩放动作触发）。

## Impact

- **后端**（backend 子仓库）：
  - `ssh/PtyCommandScheduler`：空闲超时 watchdog（`lastActivityNanos` 由输出帧刷新、按 `min(timeout-idle, maxAbs-elapsed)` 续排）+ `DEFAULT_MAX_ABSOLUTE_MS` 绝对上限 + `ptyWaitCeilingSeconds` 供等待方对齐 + `interruptCurrent`。
  - `support/TurnCancelledException`（新增）、`approval/ApprovedCommandRunner`、`ai/AgentTools`、`ai/AiAgentService`（stopRequested / inFlightSession / runReadOnly 识别重抛 / 检查点）。
- **前端**（frontend 子仓库）：终端容器尺寸同步链路（`syncSize(force)` + ResizeObserver + 会话采纳 refit 补发 resize）。
- **测试**：`PtyCommandSchedulerTest`（27 用例）、`AiAgentServiceTest` BUG-B 三用例（TOOL_RESULT 不回喂 + stop 命中调度器）、前端尺寸同步用例；后端全量 767/767、前端全量 273/273 通过。
- **文档**：`.qoder/known-issues.md` 已回写 #21/#22/#23。
