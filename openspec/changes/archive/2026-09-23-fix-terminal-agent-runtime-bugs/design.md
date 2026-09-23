# Design: 修复终端与 Agent 运行时三 BUG

## Context

动机见 proposal.md - Why；行为契约见 specs/ 下三个 delta。当前状态与约束：

- 后端经 SSH 持久 PTY 执行命令，`PtyCommandScheduler` 是所有 Agent 命令（审批后执行 + 只读工具）的必经仲裁点；`ApprovedCommandRunner`（审批执行）与 `AgentTools`（只读工具）各自在 PTY 通道失败时保留「回落非交互 exec」回退路径。
- Agent 回合跑在工作线程池上，`AiAgentService.stop()` 经 `inFlight` 表找到工作线程 `interrupt()`；langchain4j/reactor 阻塞流式读会把 InterruptedException 包成 RuntimeException（前次变更已接 cause 链识别，见 known-issues #20）。
- 前端为 per-tab xterm 实例（上一变更已确立），远端 PTY 初值为软件默认 80x24，尺寸只能靠显式 resize 帧改变。
- 测试替身环境（单测）与真实 PTY 行为存在差异：中断在替身路径上可能在命令发送前就被拦住，导致「命令未重跑」类断言不可观测（RED 假绿教训，见 tasks 证据）。

## Goals / Non-Goals

**Goals:**
- 超时语义对齐用户心智："卡住没反应才打断"，而非"跑太久就杀掉"
- 停止信号从 UI 到远端 PTY 全链路穿透，任何中间层不得把"用户停止"降级为"工具失败"
- 远端 PTY 尺寸与本地可见终端在任意入口（首连/重挂载/切 tab）保持一致

**Non-Goals:**
- 不改动审批契约与前端 UI 形状（弹窗/徽章机制不变）
- 不实现「停止后撤销已发生的远端副作用」（语义上不可能保证，维持既有声明）
- 不为绝对上限新增配置项（30 分钟内置常量已覆盖极端场景；将来有需要再走变更）
- 不处理 SFTP 通道的超时（本变更只治理 PTY 命令通道）

## Decisions

### D1（BUG-A）空闲超时 + 独立绝对上限，替代一次性绝对定时器
- **决策**：watchdog 由「dispatch 时 `schedule(timeout)` 一次」改为「按 `min(timeout - idle, maxAbs - elapsed)` 续排」，`lastActivityNanos` 在每次采集到输出帧（collectOutput/onFrame）时刷新；新增 `DEFAULT_MAX_ABSOLUTE_MS = 30min` 防跑飞。等待方 `future.get` 统一经 `PtyCommandScheduler.ptyWaitCeilingSeconds(settings) = max(settings, 1800+10)` 计算，保证**内层（调度器）先超时、外层（runner/tools）后超时**。
- **备选**：①直接把配置超时调大（如 30 分钟）——治标：卡住的命令要等同样久才被打断，且用户设置被剥夺语义；②前端展示"仍在运行"后台继续——引入长任务状态机，YAGNI。
- **理由**：Bash/PTY 世界通行做法（expect 的 timeout 即空闲语义）；双层等待必须错开，否则外层先断会把「调度器还在正常工作」误判为无结果、触发 exec 回落**重跑同一命令**（远端二次副作用）。

### D2（BUG-B）显式 `TurnCancelledException` + 权威停止标志集合，双保险穿透
- **决策**：
  - 新增 `support/TurnCancelledException`（RuntimeException，cause 约定为 InterruptedException 或 null）：类型本身即「用户停止」标记，`causedByInterrupt` 按类型直接命中。三处吞点改为透传：`ApprovedCommandRunner.tryPtyPath` 与 `AgentTools.tryPtyPath` 的 `catch (InterruptedException)` 从 `return null`（回落信号）改抛 TurnCancelled；`AgentTools.executeOrReturnError` 在 `catch (RuntimeException)` 前加 TurnCancelled rethrow（否则被伪装成 tool_result(ERROR) 回喂模型）；`AiAgentService.runReadOnly` 对包装异常先 `causedByInterrupt` 识别再重抛。
  - `AiAgentService` 维护 `Set<UUID> stopRequested`（ConcurrentHashMap.newKeySet）：`stop()` 置位、回合收尾清除；检查点三处——工具循环轮首、每次工具执行前、流式增量 chunk 循环。中断标志只作加速，不作唯一真相。
  - `stop()` 经 `inFlightSession`（conversation→session 映射，runTurn 登记、finally 清除）调 `AgentTools.interruptInFlightCommand(sessionId)` → `PtyCommandGateway.findScheduler(...).interruptCurrent()`，把 Ctrl-C 送到远端在飞命令。
- **备选**：①只靠 `Thread.interrupt()`——已被证伪：只要有一层 catch 后不 rethrow，链路即断（这正是本 BUG 根因）；②轮询"取消令牌"对象贯穿每层——改动面大，且既有 `inFlight` 表已有会话粒度，Set 成员判断等效更小。
- **理由**：中断（interrupt）是**带外信号**、易被吞；标志（flag）是**带内数据**、每个推进点必须查。二者正交叠加，任何单层的吞异常行为都最多延迟、不能阻止终止。

### D3（BUG-C）前端在「实例可见即同步」的三个时机强制补发 winsize
- **决策**：`syncSize(force)` 支持忽略缓存强制发送；ResizeObserver 观察容器尺寸变化；终端实例挂载/采纳既有会话时 refit 后**补发一次**当前真实行列（上一变更的 refit 只重排本地、不发 resize 帧，是本次断链点）。隐藏实例不发零尺寸。
- **备选**：①后端建 PTY 时从连接请求参数取初始尺寸——浏览器在 WS 建立前拿不到最终布局（字体加载/滚动条占位），初值仍会错；②定时轮询尺寸——浪费且延迟高。
- **理由**：唯一知道真实行列的是渲染端 xterm；「布局稳定后事件驱动 + 采纳时一次强发」覆盖首连、切 tab、窗口缩放全部入口，与既有 ssh 客户端（xterm.js + fit addon + resize 消息）通行做法一致。

### D4 RED 断言选「必然可观测痕迹」而非「否定式行为」
- **决策**：BUG-B 的 RED 用例不断言「exec 未重跑」（替身环境下命令发送前即被拦，不可观测 → 假绿），改断言「停止后不得出现 TOOL_RESULT 帧」「stop 必须调用 scheduler.interruptCurrent()」——选择停止被吞时**必然产生**的帧/调用作为观测量。
- **理由**：「不得发生 X」型断言必须换成「X 的必然指纹不得出现」，否则测试环境差异会悄悄让 RED 用例先天通过。

## Risks / Trade-offs

- [空闲超时误判：命令长时间静默但活着（如大文件 cp 无进度输出）] → 绝对上限 30 分钟兜底仍在；该语义与所有交互式 ssh 客户端一致，用户可感知（"执行超时"提示），属可接受权衡。
- [stopRequested 检查点间隙：模型端点阻塞读最长一个 chunk 间隔内不可中断] → interrupt() 作带外加速已覆盖大部分场景；残余延迟为秒级，浏览器实证接受。
- [双保险下"停止"与"自然收尾"竞态可能出现停止注记与 final 帧交错] → 前端本地闭环幂等（双份注记可接受，丢帧不可接受，沿袭 known-issues #20 第五层决策）。
- [强发 winsize 与远端 vim/top 全屏程序重排竞态] → 只发一次且带真实行列（非 0），隐藏实例绝不发送，实测无异常。

## Migration Plan

纯行为修复，无数据迁移、无契约变更。部署 = 重启后端 + 刷新前端；回滚 = 还原子仓库指针。
