---
name: openspec-archive-change
description: 在实验性工作流中归档一个已完成的变更。当用户想在实施完成后最终敲定并归档一个变更时使用。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.11.0"
---

在实验性工作流中归档一个已完成的变更。

**Store 选择：** 如果用户指名了一个 store（store 是注册在本机上的独立 OpenSpec 仓库），或工作内容位于某个 store 中，先运行 `openspec store list --json` 发现已注册的 store id，然后在那些读写 specs 与 changes 的命令（`new change`、`status`、`instructions`、`list`、`show`、`validate`、`archive`、`doctor`、`context`、`schemas`、`view`）上传入 `--store <id>`。一旦选定，在后续整个工作流中都固定携带 `--store <id>`。下文所有未带该标志的命令示例都是简写：运行前请补上该标志。例如，运行 `openspec status --change "<name>" --json --store "<id>"`，而非下文所示的未带标志形式。其他命令不接受该标志。命令打印的提示已自带该标志；在后续操作中保持它。若没有 store，命令作用于最近的本地 `openspec/` 根目录。

`<capability-path>` 是相对于 `specs/` 的规格目录（例如 `user-auth` 或 `identity/user-auth`）。在解析每个 delta spec 对应的主 spec 时，保留该 delta spec 的完整路径。

**输入**：可选地指定一个变更名。若省略，检查能否从对话上下文推断。若含糊或有歧义，你**必须**提示用户从可用变更中选择。

**步骤**

1. **选择变更**

   如果提供了名称，就使用它。否则：
   - 若用户提到过某个变更，从对话上下文推断
   - 若只存在一个活动变更，自动选中它
   - 若有歧义，运行 `openspec list --json` 获取可用变更，并请用户选择一个

   提示时，只展示活动变更（不含已归档的）。
   若有，附上每个变更所用的 schema。

   始终声明："Using change: <name>"，并说明如何覆盖（例如 `/opsx:archive <other>`）。

   **在既有归档检查之前，加载当前的归档输入：**

   在解析出所选变更和规划根目录后，运行：
   ```bash
   openspec instructions archive --change "<name>" --json
   ```
   在此命令上保持相同的 selected-root 标志。这次查询是建议性且可选的：它只提供额外的提示输入，因此它绝不能阻塞归档。如果它以非零码退出或返回无效 JSON —— 例如在某个尚不支持此命令的较旧 CLI 上 —— 则在无 context、无 operation guidance 的情况下继续归档工作流。不要报告错误，也不要停止。

   一次成功的响应可能会省略这两个可选字段。将 `context` 视为必需的提示级输入：阅读并考虑它，并应用相关的项目事实、约定和约束。将 `operationGuidance` 视为可选的附加建议：阅读并考虑每一条，并遵循那些适用且与内置归档工作流兼容的条目。

   将这两个字段与内置步骤、明确的用户选择、已解析路径、CLI 检查以及命令契约区分开来。如果 context 与那些起控制作用的输入之一冲突，报告该冲突并保留起控制作用的值。如果指引不适用或与某个起控制作用的输入冲突，不要遵循它并说明原因。不要从这两个字段中的任何一个推断替代路径、被跳过的提示或标志，并且除非用户单独要求，否则不要把它们的文本逐字复制进 specs、变更工件或归档摘要。这些是提示级的行为契约，而非可强制执行的检查。

2. **检查工件完成状态**

   运行 `openspec status --change "<name>" --json` 检查工件完成情况。

   解析该 JSON 以理解：
   - `schemaName`：所使用的工作流
   - `planningHome`、`changeRoot`、`artifactPaths` 和 `actionContext`：路径与范围上下文
   - `artifacts`：工件列表及其状态（`done`、`skipped` 或其他）

   **如果有任何工件既不是 `done` 也不是 `skipped`**（skipped 工件满足要求 —— 该变更声明了 skip_specs）：
   - 展示警告，列出未完成的工件
   - 请用户确认他们想要继续
   - 若用户确认则继续

3. **检查任务完成状态**

   阅读任务文件（通常是 `tasks.md`）以检查未完成的任务。

   统计标记为 `- [ ]`（未完成）与 `- [x]`（已完成）的任务数量。

   **若发现未完成的任务：**
   - 展示警告，显示未完成任务的数量
   - 请用户确认他们想要继续
   - 若用户确认则继续

   **若不存在任务文件：** 继续，不带任务相关警告。

4. **评估 delta spec 同步状态**

   将 status JSON 中的 `artifactPaths.specs.existingOutputPaths` 作为唯一的 delta-spec 来源。如果 `specs` 条目缺失或 `existingOutputPaths` 为空，则继续而不给出同步提示，且不要从其他工件推断 delta specs。

   **若存在 delta specs：**
   - 将每个 delta spec 与其对应的主 spec（位于 `<planningHome.root>/openspec/specs/<capability-path>/spec.md`）进行比较（使用第 2 步中那个 store 感知的 `planningHome.root`，而非硬编码的仓库路径）
   - 确定将会应用哪些变更（新增、修改、移除、重命名）
   - 在提示之前展示一份合并摘要

   **提示选项：**
   - 若需要变更："立即同步（推荐）"、"不同步直接归档"
   - 若已同步："立即归档"、"仍然同步"、"取消"

   根据回答进行路由：
   - "取消" —— 停止，不归档
   - "不同步直接归档" 或 "立即归档" —— 继续归档
   - "立即同步" 或 "仍然同步" —— 同步，然后验证（见下文）
   - 其他任何回答 —— 再次询问，而不是归档

   在一次被选中的 sync 写入任何主 spec 之前，用相同的 selected-root 标志运行一次 `openspec instructions specs --change "<name>" --json`。要求零退出状态和有效的 artifact-instruction JSON。如果这次查询失败或返回无效 JSON，在写入任何主 spec 或移动该变更之前报告错误并停止。一个省略了 `rules` 的有效响应即为无规则的情形。仅将返回的 `rules` 应用于本次合并所产出主 specs 的内容与形式；不要把它们当作归档指引、改变 CLI 行为，或把规则文本复制进任何输出文件。

   然后针对变更 '<name>' 内联运行 `openspec-sync-specs` 工作流（由代理驱动的智能合并），传入上面的 delta spec 分析和已获取的 specs-rule 快照，并等待它完成。内联的 sync 必须复用那份快照，而不再次获取 `specs` 说明。不要把它委派给后台任务 —— 第 5 步会把 `changeRoot` 从一个仍在读取它的 sync 底下移走，导致变更被归档而主 specs 从未更新。如果你的代理只能通过委派来运行它，那就同步委派并等待结果。

   然后从本步骤开头重新运行比较，针对 `artifactPaths.specs.existingOutputPaths` 中每一个拥有 delta spec 的 capability —— 而不只是 sync 报告它触及的那些。一次成功的 sync 会不留任何待应用的内容，因此每个 capability 现在都必须显示为已同步：
   - ADDED 需求已存在
   - MODIFIED 需求携带 delta 中点名的场景与描述变更，且它们的其他场景保持完好
   - REMOVED 需求已消失 —— 并且在本次 sync 退役了某个 capability（移除了它的最后一条需求，使 `## Requirements` 变空）之处，它的主 spec 被删除而非留空；一个被 sync 刻意保留并报告的 spec 同样算作匹配
   - RENAMED 需求以新名存在、以旧名不再存在

   如果 sync 失败，或任何 capability 不匹配，报告差异所在并停止 —— 不要归档。什么都还没被移动，`changeRoot` 完好无损，因此用户可以修复不匹配，或重新运行 sync 并再次开始归档。

5. **执行归档**

   若 `planningHome.changesDir` 下不存在 `archive` 目录，则创建它：
   ```bash
   mkdir -p "<planningHome.changesDir>/archive"
   ```

   生成目标名称：当变更名已以 `YYYY-MM-DD-` 前缀开头时，原样使用它；否则以 `YYYY-MM-DD-<change-name>` 的形式在当前日期前置。绝不叠加第二个日期（与 `openspec archive` 规则相同）。

   **检查目标是否已存在：**
   - 若是：以错误失败，建议重命名既有归档或使用不同日期
   - 若否：将 `changeRoot` 移动到 archive 目录

   ```bash
   mv "<changeRoot>" "<planningHome.changesDir>/archive/<target-name>"
   ```

6. **展示摘要**

   展示归档完成摘要，包括：
   - 变更名
   - 所用的 schema
   - 归档位置
   - specs 是否已同步（若适用）
   - 关于任何警告的说明（未完成的工件/任务）

**成功时的输出**

```markdown
## 归档完成

**变更：** <change-name>
**Schema：** <schema-name>
**归档至：** 由 `planningHome.changesDir`/<target-name>/ 派生出的归档路径
**Specs：** <仅当第 4 步验证通过时为 "✓ 已同步到主 specs"；否则为 "无 delta specs" 或 "跳过同步">

<"所有工件已完成。所有任务已完成。" —— 或者，若带警告归档，则改为列出它们（例如 "归档时有 2 个未完成的任务"）>
```

**护栏**
- 声明所选变更；当它有歧义时提示选择
- 使用工件图（openspec status --json）进行完成情况检查
- 不要因为警告而阻塞归档 —— 只需告知并确认
- 移动到归档时保留 .openspec.yaml（它随目录一起移动）
- 清晰展示发生了什么的摘要
- 若请求了同步，内联运行 `openspec-sync-specs` 工作流（由代理驱动）
- 绝不在某次 spec 同步仍在进行中时归档 —— 内联运行该 sync 并在移动 `changeRoot` 之前验证主 specs
- 若存在 delta specs，始终运行同步评估并在提示之前展示合并摘要
- 应用相关的运行时 context 并报告冲突；operation guidance 仍为建议性
- 考虑每一条指引条目，并解释任何不适用或冲突的建议
- 既有的 CLI 检查、已解析路径、提示和命令契约保持不变
- 工件规则仅约束正在写入的 specs，绝不是 operation guidance
- 绝不把运行时 context、operation guidance 或工件规则文本逐字复制进输出文件
