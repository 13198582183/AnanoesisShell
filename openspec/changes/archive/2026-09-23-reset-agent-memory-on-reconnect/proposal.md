# Proposal: reset-agent-memory-on-reconnect

## Why

用户反馈（BUG-E）："当用户同一个 tab 窗口重连时，应该清理掉之前这个窗口执行的 agent 的记忆，重置。"

现状缺陷：每个 tab 的 Agent 记忆 = 绑定的 `conversationId`（后端按 conversation 加载历史消息回喂模型），首次 Agent 提问时创建后**整个 tab 生命周期内永不重置**（甚至持久化进 localStorage）。而重连（`r` 键 / 重连按钮）会重建一个**全新的终端会话**——工作目录、环境变量、运行中程序全部丢失。此时若 Agent 仍携带旧对话记忆，模型会：

- 误认旧会话的 cwd（"当前目录"指向已不存在于新 shell 的路径认知）；
- 以为之前执行过的安装/配置仍生效（新 shell 可能连那些进程/临时状态都没有）；
- 引用死会话里的命令结果做决策，产生与实况脱节的"幻觉上下文"。

这与 spec 已有的"新会话为全新 Shell（目录重置为登录目录）"边界一致——终端实况重置了，Agent 记忆也必须同步重置，否则两者语义割裂。

## What Changes

- **重连即重置 Agent 对话记忆**：`reconnectWorkspace`（r 键与重连按钮的唯一汇聚点）在守卫通过、确认发起重连时，解绑该 tab 的 `conversationId`（置 null）→ 下次 Agent 提问自动新建 conversation → 记忆从零开始。
- **边界注记**：重置发生时终端写入一行青色提示"终端会话已重建，Agent 对话记忆已重置（…旧历史可在历史面板查看）"，与既有断线提示行同风格；首连无旧记忆不写，避免噪音。
- **流式锁同步解除**：解绑时复位该 tab 的 `aiStreamingByWs` 标志——旧对话收尾帧会被 conversation 归属过滤，不解除则该 tab 输入永久阻塞（连带修复潜在卡死）。
- **store 契约扩展**：`setConversationId(id, conversationId)` 参数放宽为 `string | null`（null=解绑，与 `setSessionId` 同构）。
- **不删除历史**：旧 conversation 及其消息仍完整留在库中（审计与历史面板可查），仅不再被本 tab 引用——与"历史保留"既有约束一致。
- **后端零改动**：记忆按 conversationId 加载，前端换新 id 即天然清零。

## Capabilities

### Modified Capabilities

- `terminal-workspace`：「断线重连」需求追加"重连 MUST 重置 Agent 对话记忆"契约（新增 1 场景，既有 3 场景名全部保留）。

## Impact

- **代码**：`frontend/src/views/WorkspaceView.vue`（reconnectWorkspace 增重置块）、`frontend/src/stores/workspaces.ts`（setConversationId 类型放宽 + JSDoc）。
- **测试**：`WorkspaceView.spec.ts` +2 用例（重连重置+注记 / 首连不写注记）、`workspaces.spec.ts` +1 用例（null 解绑）；前端全量 276/276、type-check 干净。
- **协议 / DB / 后端**：无变更。
- **兼容性**：依赖"重连后 Agent 仍记得旧对话"的隐性行为被撤销——这正是用户要求；跨 F5 刷新的 conversationId 持久化保留（刷新非重连语义，不在此列）。
