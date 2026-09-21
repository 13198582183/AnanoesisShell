---
name: "OPSX: Update"
description: "更新一个变更 —— 修订已有的规划工件并保持它们彼此一致（实验性）"
category: "Workflow"
tags: ["workflow", "artifacts", "experimental"]
---

修订某个变更已有的规划工件（planning artifacts）并保持它们彼此一致。绝不编辑代码。

**Store 选择：** 如果用户指名了一个 store（store 是注册在本机上的独立 OpenSpec 仓库），或工作内容位于某个 store 中，先运行 `openspec store list --json` 发现已注册的 store id，然后在那些读写 specs 与 changes 的命令（`new change`、`status`、`instructions`、`list`、`show`、`validate`、`archive`、`doctor`、`context`、`schemas`、`view`）上传入 `--store <id>`。一旦选定，在后续整个工作流中都固定携带 `--store <id>`。下文所有未带该标志的命令示例都是简写：运行前请补上该标志。例如，运行 `openspec status --change "<name>" --json --store "<id>"`，而非下文所示的未带标志形式。其他命令不接受该标志。命令打印的提示已自带该标志；在后续操作中保持它。若没有 store，命令作用于最近的本地 `openspec/` 根目录。

**输入**：可在 `/opsx:update` 后可选地指定变更名（例如 `/opsx:update add-auth`）。若省略，检查能否从对话上下文推断。若含糊或有歧义，你**必须**提示用户从可用变更中选择。

`/opsx:continue` 是可选工作流，可能未安装。在下文任何位置建议它之前，先确认它可用。若不可用，`openspec status --change "<name>" --json` 会显示下一个工件，`openspec instructions "<artifact-id>" --change "<name>" --json` 会说明如何创建它。

**步骤**

1. **选择变更**

   如果提供了名称，就使用它。否则：
   - 若用户提到过某个变更，从对话上下文推断
   - 若只存在一个活动变更，自动选中它
   - 若有歧义，运行 `openspec list --json` 获取按最近修改时间排序的可用变更，并请用户选择一个

   提示时，展示最近修改的前 3-4 个变更作为选项，显示：
   - 变更名称
   - Schema（若存在 `schema` 字段则取其值，否则为 "spec-driven"）
   - 状态（例如 "0/5 tasks"、"complete"、"no tasks"）
   - 最近修改时间（取自 `lastModified` 字段）

   将最近修改的变更标记为 "(Recommended)"，因为它很可能就是用户想更新的对象。

   始终声明："Using change: <name>"，并说明如何覆盖（例如 `/opsx:update <other>`）。

2. **获取变更的工件**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析该 JSON 以了解当前状态。响应包含：
   - `schemaName`：所用工作流 schema（例如 "spec-driven"）
   - `artifacts`：工件数组及其状态（"done"、"skipped"、"ready"、"blocked"）
   - `isPlanningComplete`：布尔值，指示所有规划工件是否已完成。较旧的 CLI 版本以 `isComplete` 暴露同一值。
   - `planningHome`、`changeRoot`、`artifactPaths` 和 `actionContext`：路径与作用域上下文。使用它们，而不要假定为仓库本地路径。

   工件 id 与路径来自当前活动的 schema —— **不要**臆测它们，也**不要**基于硬编码的工件名做分支判断。自定义 schema 必须能原样工作。

   要编辑的文件是 `artifactPaths.<id>.existingOutputPaths` —— 即磁盘上真实存在的具体文件，对 glob 工件而言已做 glob 展开（例如 `specs/**/*.md`）。**不要**写入 `resolvedOutputPath`：对 glob 工件来说它仍是 glob 模式，而非真实文件。

3. **理解请求**
   - 如果用户要求了某项具体修订（"设计现在改用 X"），那就是起始编辑点。
   - 如果他们只说"更新" / "让它保持一致"，则视为一致性审查：阅读已有工件，并相互比对，查找矛盾、缺口与重复。

4. **阅读并调和**
   - 阅读请求涉及的那些工件，以及该变更的其他已有工件。
   - 应用所请求的编辑。然后将其他每个已有工件与之比对 —— **任意方向**都要比：对较晚工件的编辑可能需要修订较早的工件，而不仅是相反方向。构建顺序是有用的阅读顺序，并非对"哪些工件可被修订"的约束。
   - 记录现在所有不一致、缺失或矛盾之处。
   - 只修订已存在的文件（`existingOutputPaths`）。**不要**创建尚不存在的工件，也**不要**在 glob 工件下凭空新增文件 —— 记录它们，并指引用户用 `/opsx:continue` 去创建。
   - 如果该变更已经一致，就如此说明，不做任何编辑。

5. **逐个工件地确认并应用**
   - 展示每项拟议修订及其理由。仅在用户确认后才写入。
   - 若用户拒绝某项修订，就不要写入 —— 保持该工件不变。
   - 当需要大幅重写时，先获取该工件的规则与模板：
     ```bash
     openspec instructions "<artifact-id>" --change "<name>" --json
     ```

6. **指明下一步（仅作指引 —— 绝不去执行它）**
   - 仍有工件缺失 -> 建议用 `/opsx:continue` 创建它们。
   - 变更已实现（任务已勾选 / 已 apply）-> 代码可能不再与修订后的计划吻合；建议用 `/opsx:apply` 把差异落入代码。
   - 全部完成且已实现 -> 建议 `/opsx:archive`。

**输出**

每次调用后，展示：
- 哪些工件被修订（以及哪些拟议修订被拒绝）
- 任何推迟给 `/opsx:continue` 的事项（尚未创建的工件或文件）
- 该变更当前所处状态，以及推荐的下一条命令

**护栏**
- 仅限规划工件 —— **绝不**编辑实现代码。若修订后的计划意味着代码改动，停下并指向 `/opsx:apply`。
- 使用 `openspec status` 报告的工件 id 与路径；绝不基于硬编码的工件名做分支。
- 只编辑 `existingOutputPaths` 中的具体文件；绝不写入 glob 的 `resolvedOutputPath`。
- 不要推进构建前沿（build frontier）：不新增工件、不在 glob 工件下新增文件 —— 那是 `/opsx:continue` 的职责。
- 写入前，与用户确认每一项编辑。
- 如果请求改变的是该变更的*意图*而非细化它，先确认可选的 `/opsx:new` 工作流是否可用。若可用，推荐用 `/opsx:new` 重新开始（"更新 vs. 全新开始"启发式）。若不可用，则请求一个未被使用的、不同的变更名，并改为推荐 `openspec new change "<new-change-name>"`。
