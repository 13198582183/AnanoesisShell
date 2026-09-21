---
name: openspec-apply-change
description: 实施来自 OpenSpec 变更的任务。当用户想要开始实施、继续实施，或逐步处理任务时使用。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.11.0"
---

实施来自 OpenSpec 变更的任务。

**Store 选择：** 如果用户指名了一个 store（store 是注册在本机上的独立 OpenSpec 仓库），或工作内容位于某个 store 中，先运行 `openspec store list --json` 发现已注册的 store id，然后在那些读写 specs 与 changes 的命令（`new change`、`status`、`instructions`、`list`、`show`、`validate`、`archive`、`doctor`、`context`、`schemas`、`view`）上传入 `--store <id>`。一旦选定，在后续整个工作流中都固定携带 `--store <id>`。下文所有未带该标志的命令示例都是简写：运行前请补上该标志。例如，运行 `openspec status --change "<name>" --json --store "<id>"`，而非下文所示的未带标志形式。其他命令不接受该标志。命令打印的提示已自带该标志；在后续操作中保持它。若没有 store，命令作用于最近的本地 `openspec/` 根目录。

**输入**：可选地指定一个变更名（例如 `/opsx:apply add-auth`）。若省略，检查能否从对话上下文推断。若含糊或有歧义，你**必须**提示用户从可用变更中选择。

**步骤**

1. **选择变更**

   如果提供了名称，就使用它。否则：
   - 若用户提到过某个变更，从对话上下文推断
   - 若只存在一个活动变更，自动选中它
   - 若有歧义，运行 `openspec list --json` 获取可用变更，并请用户选择一个

   始终声明："Using change: <name>"，并说明如何覆盖（例如 `/opsx:apply <other>`）。

2. **检查 status 以理解 schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析该 JSON 以理解：
   - `schemaName`：所使用的工作流（例如 "spec-driven"）
   - `planningHome`、`changeRoot` 和 `actionContext`：规划范围与编辑约束
   - 哪个工件包含任务（spec-driven 通常是 "tasks"，其他的检查 status）

3. **获取 apply 说明**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   它返回：
   - `contextFiles`：工件 ID -> 具体文件路径的数组（因 schema 而异 —— 可能是 proposal/specs/design/tasks 或 spec/tests/implementation/docs）
   - 进度（total、complete、remaining）
   - 带状态的任务列表
   - 基于当前状态的动态指令
   - 可选的 `context`：来自所选根目录的、当前必需的项目指令输入
   - 可选的 `operationGuidance`：针对 apply 的当前建议性指引

   **处理各种状态：**
   - 若 `state: "blocked"`（缺失工件）：展示消息，建议使用 `/opsx:continue`（若它未安装，运行 `openspec status --change "<name>" --json` 查看下一个工件，并运行 `openspec instructions <artifact-id> --change "<name>" --json` 了解如何创建它）
   - 若 `state: "all_done"`：祝贺，建议归档
   - 否则：继续进行实施

   将 `context` 视为必需的提示级输入。阅读并考虑它，并在实施时应用相关的项目事实、约定和约束。将 `operationGuidance` 视为可选的附加建议。阅读并考虑每一条，并遵循那些适用且与内置工作流兼容的条目。

   将这两个字段与 CLI 返回的状态、缺失工件、任务、进度、`contextFiles` 以及内置 `instruction` 区分开来。它们不是任务完成的证据，不能替代内置指令，也不允许绕过 blocked 状态。如果 context 与内置指令、某个明确的用户选择，或某个 CLI 控制的值冲突，报告该冲突并保留起控制作用的值。如果指引不适用或与那些起控制作用的输入冲突，不要遵循它并说明原因。这些是提示级的行为契约，而非可强制执行的检查。

4. **阅读 context files**

   阅读 apply 说明输出中 `contextFiles` 下列出的每一个文件路径。
   这些文件取决于所使用的 schema：
   - **spec-driven**：proposal、specs、design、tasks
   - 其他 schema：遵循 CLI 输出中的 contextFiles

   除非用户单独要求那些内容，否则不要把 `context` 或 `operationGuidance` 逐字复制进实施文件或规划工件。

5. **展示当前进度**

   展示：
   - 所使用的 schema
   - 进度："N/M 个任务已完成"
   - 剩余任务概览
   - 来自 CLI 的动态指令

6. **实施任务（循环直到完成或阻塞）**

   对每个待处理任务：
   - 展示正在处理哪个任务
   - 做出所需的代码变更
   - 保持变更最小化且聚焦
   - 在任务文件中标记任务完成：`- [ ]` → `- [x]`
   - 继续下一个任务

   **在以下情况暂停：**
   - 任务不清楚 → 请求澄清
   - 实施揭示出设计问题 → 建议更新工件
   - 某个任务需要超出 spec 和 tasks 所描述范围的工作，或你想通过丢弃、收窄、推迟，或接受对既定行为的例外来使它勉强适配 → 揭示这些新增范围并发问；不要静默吸收它
   - 遇到错误或阻塞 → 报告并等待指引
   - 用户打断

7. **在完成或暂停时，展示状态**

   展示：
   - 本次会话完成的任务
   - 总体进度："N/M 个任务已完成"
   - 若全部完成：建议归档
   - 若暂停：说明原因并等待指引

**实施期间的输出**

```
## 正在实施：<change-name>（schema：<schema-name>）

正在处理任务 3/7：<task description>
[...实施进行中...]
✓ 任务完成

正在处理任务 4/7：<task description>
[...实施进行中...]
✓ 任务完成
```

**完成时的输出**

```
## 实施完成

**变更：** <change-name>
**Schema：** <schema-name>
**进度：** 7/7 个任务已完成 ✓

### 本次会话已完成
- [x] 任务 1
- [x] 任务 2
...

所有任务已完成！你可以用 `/opsx:archive` 归档此变更。
```

**暂停时的输出（遇到问题）**

```
## 实施已暂停

**变更：** <change-name>
**Schema：** <schema-name>
**进度：** 4/7 个任务已完成

### 遇到的问题
<description of the issue>

**选项：**
1. <option 1>
2. <option 2>
3. 其他方式

你想怎么做？
```

**护栏**
- 持续推进任务，直到完成或阻塞
- 开始前始终阅读 context files（来自 apply 说明输出）
- 如果任务有歧义，在实施前暂停并发问
- 如果实施揭示出问题，暂停并建议更新工件
- 保持代码变更最小化，并限定在每个任务的范围内
- 每完成一个任务后，立即更新任务复选框
- 遇到错误、阻塞或不清楚的需求时暂停 —— 不要猜测
- 当某个任务需要超出 spec 所描述范围的工作时，揭示新增范围并暂停 —— 绝不静默地收窄、推迟，或简化掉既定行为
- 仅当某个任务的既定行为被完全实施时，才把它标记为 `- [x]`；部分完成或被推迟时不要标记
- 使用来自 CLI 输出的 contextFiles，不要假设具体的文件名
- 不要把 context 或 operation guidance 当作某个任务已完成的证据
- 应用相关的项目上下文；报告与起控制作用的工作流输入之间的冲突
- 考虑每一条指引条目；解释任何不适用或冲突的建议
- 不要把运行时 context 或 operation guidance 复制进实施文件或规划工件
- 保留由 CLI 控制的 blocked/ready/all-done 行为与完成判据

**流动式工作流集成**

本技能支持"针对一个变更的动作"模型：

- **可随时调用**：在所有工件完成之前（若任务已存在）、部分实施之后，或与其他动作交错进行
- **允许更新工件**：如果实施揭示出设计问题，建议更新工件 —— 不锁定阶段，工作流动进行
