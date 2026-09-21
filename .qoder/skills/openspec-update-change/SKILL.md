---
name: openspec-update-change
description: 通过修订一个 OpenSpec 变更已有的规划工件并使它们彼此保持一致来更新它。当用户想修订某个变更的计划、把新决定并入其中，或在一次编辑后调和它的工件时使用。绝不编辑代码。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.11.0"
---

修订某个变更已有的规划工件并使它们保持一致。绝不编辑代码。

**Store 选择：** 如果用户指名了一个 store（store 是注册在本机上的独立 OpenSpec 仓库），或工作内容位于某个 store 中，先运行 `openspec store list --json` 发现已注册的 store id，然后在那些读写 specs 与 changes 的命令（`new change`、`status`、`instructions`、`list`、`show`、`validate`、`archive`、`doctor`、`context`、`schemas`、`view`）上传入 `--store <id>`。一旦选定，在后续整个工作流中都固定携带 `--store <id>`。下文所有未带该标志的命令示例都是简写：运行前请补上该标志。例如，运行 `openspec status --change "<name>" --json --store "<id>"`，而非下文所示的未带标志形式。其他命令不接受该标志。命令打印的提示已自带该标志；在后续操作中保持它。若没有 store，命令作用于最近的本地 `openspec/` 根目录。

**输入**：可选地指定一个变更名。若省略，检查能否从对话上下文推断。若含糊或有歧义，你**必须**提示用户从可用变更中选择。

`/opsx:continue` 是一个可选工作流，可能未安装。在下文任何地方建议它之前，先验证它是否可用。若不可用，`openspec status --change "<name>" --json` 会显示下一个工件，`openspec instructions "<artifact-id>" --change "<name>" --json` 会说明如何创建它。

**步骤**

1. **选择变更**

   如果提供了名称，就使用它。否则：
   - 若用户提到过某个变更，从对话上下文推断
   - 若只存在一个活动变更，自动选中它
   - 若有歧义，运行 `openspec list --json` 获取按最近修改排序的可用变更，并请用户选择一个

   提示时，把最近修改的前 3-4 个变更作为选项呈现，显示：
   - 变更名
   - schema（若有则取自 `schema` 字段，否则为 "spec-driven"）
   - 状态（例如 "0/5 tasks"、"complete"、"no tasks"）
   - 它最近被修改的时间（取自 `lastModified` 字段）

   将最近修改的那个变更标记为 "(Recommended)"，因为它很可能就是用户想更新的。

   始终声明："Using change: <name>"，并说明如何覆盖（例如 `/opsx:update <other>`）。

2. **获取该变更的工件**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析该 JSON 以理解当前状态。响应包含：
   - `schemaName`：所使用的工作流 schema（例如 "spec-driven"）
   - `artifacts`：工件数组及其状态（"done"、"skipped"、"ready"、"blocked"）
   - `isPlanningComplete`：布尔值，指示所有规划工件是否已完成。较旧的 CLI 版本以 `isComplete` 暴露同一个值。
   - `planningHome`、`changeRoot`、`artifactPaths` 和 `actionContext`：路径与范围上下文。使用它们，而不要假设仓库本地路径。

   工件 id 和路径来自活动的 schema —— 不要假设它们，也不要基于硬编码的工件名进行分支。自定义 schema 必须能原样工作。

   要编辑的文件是 `artifactPaths.<id>.existingOutputPaths` —— 磁盘上真实存在的具体文件，对 glob 工件已做过 glob 展开（例如 `specs/**/*.md`）。不要写入 `resolvedOutputPath`：对一个 glob 工件而言，它仍是那个 glob 模式，而非真实文件。

3. **理解请求**
   - 如果用户要求了一个具体的修订（"设计现在改用 X"），那就是起始编辑。
   - 如果他们只说了 "update" / "make this coherent"，把它当作一次一致性审查：阅读既有工件并相互对照，检查矛盾、缺漏和重复。

4. **阅读并调和**
   - 阅读该请求触及的工件，以及该变更的其他既有工件。
   - 应用所请求的编辑。然后对照它检查每一个其他既有工件 —— 沿**任意**方向：对较晚工件的一次编辑可能需要修订较早的工件，而不只是反过来。构建顺序是一种有用的阅读顺序，而非对哪些工件可被修订的约束。
   - 记下现在一切不一致、缺失或矛盾之处。
   - 只修订已存在的文件（`existingOutputPaths`）。不要创建尚不存在的工件，也不要在某个 glob 工件下臆造新文件 —— 记下它们并指引用户用 `/opsx:continue` 去创建。
   - 如果该变更已经一致，就这么说，并且不做任何编辑。

5. **逐个工件地确认并应用**
   - 展示每一处拟议的修订及其原因。仅在用户确认后才写入。
   - 如果用户拒绝某处修订，不要写它 —— 让那个工件保持不变。
   - 当需要大幅重写时，先获取那个工件的规则和模板：
     ```bash
     openspec instructions "<artifact-id>" --change "<name>" --json
     ```

6. **指向下一步（仅作指引 —— 绝不据此行动）**
   - 仍有工件缺失 -> 建议用 `/opsx:continue` 创建它们。
   - 变更已实施（任务已勾选 / 已 apply）-> 代码可能不再与修订后的计划匹配；建议用 `/opsx:apply` 把差异带入代码。
   - 一切都已完成并实施 -> 建议 `/opsx:archive`。

**输出**

每次调用后，展示：
- 哪些工件被修订了（以及哪些拟议修订被拒绝了）
- 任何被推迟给 `/opsx:continue` 的内容（尚未创建的工件或文件）
- 该变更目前所处状态，以及推荐的下一条命令

**护栏**
- 仅限规划工件 —— 绝不编辑实施代码。如果修订后的计划意味着代码变更，停止并指向 `/opsx:apply`。
- 使用 `openspec status` 报告的工件 id 和路径；绝不基于硬编码的工件名进行分支。
- 只编辑 `existingOutputPaths` 中的具体文件；绝不写入一个 glob 的 `resolvedOutputPath`。
- 不要推进构建前沿：不新增工件，不在 glob 工件下新增文件 —— 那是 `/opsx:continue` 的职责。
- 写入前与用户确认每一处编辑。
- 如果该请求改变的是这个变更的*意图*、而非对它进行细化，先验证可选的 `/opsx:new` 工作流是否可用。若可用，推荐用 `/opsx:new` 从头开始（即 "Update vs. Start Fresh" 启发式）。若不可用，则索要一个不同的、未使用过的变更名，并改为推荐 `openspec new change "<new-change-name>"`。
