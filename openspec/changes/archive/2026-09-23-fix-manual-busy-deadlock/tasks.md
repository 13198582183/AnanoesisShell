# Tasks: fix-manual-busy-deadlock

## 1. RED（失败测试先行）
- [x] 1.1 `PtyCommandSchedulerTest` 新增 `createSchedulerWithBusyExpire` helper 与 ManualBusySelfHeal 嵌套 5 用例（引用不存在的 7 参构造器，编译失败确认 RED）
- [x] 1.2 修复用例④时序缺陷（初版单次 sleep(300) 使正确实现也失败 → 改为 sleep(250)+重新 busy+sleep(250) 制造新旧窗口差）

## 2. GREEN（调度器实现）
- [x] 2.1 `DEFAULT_BUSY_EXPIRE_MS=10_000` 常量（WHY javadoc 记录死锁闭环）、`busyExpireMs` 字段、6 参构造器委托新 7 参构造器
- [x] 2.2 `onManualBusy` 每次按键重排自愈任务；`scheduleBusyExpire`/`cancelBusyExpire` 私有方法
- [x] 2.3 `onBusyExpired`：锁内 `state==MANUAL_BUSY && currentCommand==null` → Ctrl-C 清行 → MANUAL_IDLE → tryDispatchNext
- [x] 2.4 `submitCommand` MANUAL_BUSY 分支改排队（enqueueCommand），javadoc 同步新语义
- [x] 2.5 `handleCmdStart` busy 且无在飞命令时取消自愈（前台程序保护）；`handlePrompt` busy→idle、`onManualIdle`、`onStopping` 取消自愈任务
- [x] 2.6 旧用例语义更新：`manualBusyBlocksAgentSubmit`→`manualBusyQueuesAgentSubmit`；删除与既有 unknown/stopping 拒绝用例重复的 `submitRejectedWhenManualBusy`（中途误改名引发重复方法编译错误，已清理）

## 3. VERIFY
- [x] 3.1 定向 `PtyCommandSchedulerTest`：31 用例 0 失败（surefire XML：tests=31 failures=0 errors=0；期间修复用例②受 200ms 命令超时 watchdog 干扰 → 命令超时拉至 5s）
- [x] 3.2 后端全量回归：`Tests run: 771, Failures: 0, Errors: 0` BUILD SUCCESS

## 4. 端到端验证
- [x] 4.1 重启后端加载新代码（旧 pid 11288 停，新 pid 30224 health=UP）
- [x] 4.2 浏览器终验：重连后输入半行 `echo SELFHEAL_PROBE`（触发 busy）→ 10s 静默→后端日志 `manual_busy 静默到期…自愈回 manual_idle` + 截图 `echo SELFHEAL_PROBE^C` 半行被清、回到干净提示符（真实 PTY 端到端）

## 5. 收尾
- [x] 5.1 `known-issues.md` 回写 MANUAL_BUSY 死锁条目 #24（症状/根因/修复/预防）
- [ ] 5.2 `openspec validate --strict` 通过 → 归档变更并同步主 specs
- [ ] 5.3 三仓提交推送（backend 修复+测试；主仓库 specs/归档/known-issues/submodule 指针）
