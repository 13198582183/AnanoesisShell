---
name: openspec-propose
description: 一步提出一个新变更并生成所有工件。当用户想快速描述他们要构建的内容，并得到一个包含 design、specs 和 tasks、可供实施的完整提案时使用。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.11.0"
---

提出一个新变更 —— 创建该变更并一步生成所有工件。

**规划边界**：本工作流只创建规划工件。选中或触发本工作流的那个用户请求仅授权规划，即便它要求构建或修复某些东西。不要编辑项目代码。规划工件完成后，停止。不要在同一条回复里开始实施，即便最初的请求要求这样做。在工件呈现之后，等待一个新的用户请求；然后再开始 apply 工作流。

我将按你的 schema 所定义的工件创建一个变更。使用默认的 spec-driven schema 时，它们是：
- proposal.md（做什么 & 为什么）
- `specs/<capability-path>/spec.md`（系统必须做什么 —— 一个 delta，而非主 spec）
- design.md（怎么做）
- tasks.md（实施步骤）

`<capability-path>` 是相对于 `specs/` 的规格目录（例如 `user-auth` 或 `identity/user-auth`）。保留已有 capability 的完整路径，并为新 capability 遵循项目既定的组织方式。

当用户准备好实施时，他们必须显式地开始 apply 工作流。

---

**Store 选择：** 如果用户指名了一个 store（store 是注册在本机上的独立 OpenSpec 仓库），或工作内容位于某个 store 中，先运行 `openspec store list --json` 发现已注册的 store id，然后在那些读写 specs 与 changes 的命令（`new change`、`status`、`instructions`、`list`、`show`、`validate`、`archive`、`doctor`、`context`、`schemas`、`view`）上传入 `--store <id>`。一旦选定，在后续整个工作流中都固定携带 `--store <id>`。下文所有未带该标志的命令示例都是简写：运行前请补上该标志。例如，运行 `openspec status --change "<name>" --json --store "<id>"`，而非下文所示的未带标志形式。其他命令不接受该标志。命令打印的提示已自带该标志；在后续操作中保持它。若没有 store，命令作用于最近的本地 `openspec/` 根目录。

**输入**：用户的请求应包含一个变更名（kebab-case），或者他们想要构建内容的描述。

**步骤**

1. **理解请求并澄清实质性歧义**

   若未提供清晰的输入，向用户提问（开放式，无预设选项）：
   > "你想处理哪个变更？描述你想构建或修复的内容。"

   从其描述中，推导出一个 kebab-case 名称（例如，"add user authentication" → `add-user-auth`）。

   **重要**：在未理解用户想构建什么之前，不要继续。

   如果请求中包含会实质性影响范围、外部可观察行为、兼容性或验收标准的歧义，在创建变更之前先询问用户。对于细枝末节，做出合理假设并记录在规划工件中。

2. **确定工作流 schema**

   使用配置好的默认 schema，除非用户显式请求不同的工作流。

   **仅在以下情况下使用不同的 schema：**
   - 用户按名称显式请求某个特定 schema → 使用 `--schema <schema-name>`
   - 要求 "show workflows" 或询问存在 "what workflows" → 从当前工作目录运行 `openspec context --json` 来解析权威根目录。如果用户显式选择了一个已注册的 store，使用 `openspec context --json --store "<store-id>"`。然后将工作目录设为返回的 `root.path` 运行 `openspec schemas --json`，并让他们选择。这会保留由本地 `store:` 指针或全局 `defaultStore` 选中的根目录；当显式选中了某个已注册 store 时，也要给 `openspec schemas --json` 追加 `--store "<store-id>"`。如果 context 只报告 `no_openspec_root`，则改为从当前工作目录运行 `openspec schemas --json`。不要对无效或不可用的 store 使用此回退方式。

   否则，省略 `--schema` 以保留配置好的默认值。

3. **创建变更目录**

   从下面选择一种 schema 形式。如果选中了某个已注册 store，给该命令以及下文所示每个接受 `--store` 的 OpenSpec 命令追加 `--store "<store-id>"`。

   使用配置好的默认值：
   ```bash
   openspec new change "<name>"
   ```

   使用显式请求的 schema：
   ```bash
   openspec new change "<name>" --schema "<schema-name>"
   ```
   这会在由 CLI 解析出的规划主目录中创建一个带 `.openspec.yaml` 的脚手架变更。

4. **获取工件构建顺序**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析该 JSON 以获取：
   - `applyRequires`：实施前所需的工件 ID 数组（例如 `["tasks"]`）
   - `artifacts`：所有工件的列表，每个都带有其 `status` 及其 `requires` 边（它直接依赖的工件 ID）
   - `planningHome`、`changeRoot`、`artifactPaths` 和 `actionContext`：路径与范围上下文。使用它们，而不要假设仓库本地路径。

5. **创建所需集合中的每一个工件**

   使用一个 todo 列表来跟踪工件的进度。

   按依赖顺序遍历工件（先处理没有待决依赖的工件）：

   a. **对每个处于 `ready`（依赖已满足）的工件**：
      - 获取说明：
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - 该说明 JSON 包含：
        - `context`：项目背景（对你的约束 —— 不要包含在输出中）
        - `rules`：工件专属规则（对你的约束 —— 不要包含在输出中）
        - `template`：你的输出文件所使用的结构
        - `instruction`：针对该工件类型的 schema 专属指引
        - `skipped`/`warning`：当变更声明了 skip_specs 且该工件**不得**被创建时出现 —— 停止并选择另一个工件
        - `resolvedOutputPath`：写入该工件的已解析路径或模式
        - `dependencies`：为获取上下文而需阅读的已完成工件
      - 阅读任何已完成的依赖文件以获取上下文 —— 始终从磁盘重新阅读它们，即便你在对话中早先见过（用户可能已编辑它们）
      - 如果 `instruction` 字段将创建委派给某个特定技能或命令，调用它来产出该工件，而不要自己写文件，然后验证工件文件存在于 `resolvedOutputPath`
      - 否则，以 `template` 为结构创建工件文件并将其写入 `resolvedOutputPath`。如果 `resolvedOutputPath` 是一个 glob，遵循 `instruction` 来选择具体的文件路径
      - 将 `context` 和 `rules` 作为约束应用 —— 但不要把它们复制进文件
      - 展示简短进度："已创建 <artifact-id>"

   b. **持续进行，直到所需集合中的每一个工件都存在（不只是 `apply.requires`）**
      - 创建每个工件后，重新运行 `openspec status --change "<name>" --json`
      - 所需集合是 `applyRequires` 加上从这些工件出发、沿 `status --json` 中的 `requires` 边可达的每一个工件 —— 传递式地遍历它们（spec-driven 闭包覆盖 proposal、specs、design、tasks）。不要动该集合之外的工件
      - `status` 仅基于文件是否存在，因此某个 `applyRequires` 工件显示 `done` 并**不**意味着它的依赖存在 —— 过早写入 `tasks.md` 会把 `tasks` 标记为 done，而 `specs` 从未被写入。使用每个工件的 `requires` 边、而非它的 `status` 来构建所需集合：一个 `done` 工件仍然会列出它所依赖的内容
      - 一个已显示 `status: "skipped"` 的工件即为已满足：该变更在 `.openspec.yaml` 中声明了 `skip_specs`，因此它的文件**不得**存在。绝不要试图创建它
      - 创建所需集合中每一个缺失的工件，然后重新检查 —— 创建一个可以解锁其他
      - 仅在 `status` 已将其报告为 `skipped`，或它自己的 `instruction` 表明它是有条件的时候，才跳过某个工件：运行 `openspec instructions <artifact-id> --change "<name>" --json`，且仅当其 `instruction` 字段将它标记为可选时才跳过（例如 "create only if..."）。spec-driven 的 `design.md` 符合此条件；`specs` 只能通过上面的 `skipped` 状态符合条件，绝不能凭你自己的判断。告知用户，并且不要再重新考虑它
      - 依赖是促成因素，而非关卡：如果某个所需工件仅仅因为你跳过了一个有条件依赖而仍处于 `blocked`，那也照样写它
      - 当所需集合中的每一个工件都是 `done`、`skipped`，或已被刻意跳过时，停止

   c. **如果某个工件需要用户输入**（上下文不清楚）：
      - 请用户澄清
      - 然后继续创建

6. **展示最终状态**
   ```bash
   openspec status --change "<name>"
   ```

**输出**

完成所有工件后，总结：
- 变更名与位置
- 已创建工件的列表及简短描述，外加你跳过的任何有条件工件及原因
- 已就绪的内容："实施所需的所有工件均已就绪。"
- 提示："工件已可供审阅。当你准备好时，运行 `/opsx:apply`，或让我来实施这个变更。"

**工件创建指引**

- 对每种工件类型，遵循来自 `openspec instructions` 的 `instruction` 字段 —— 它是权威指引，即便对于你熟悉的工件名也是如此
- 如果 `instruction` 字段指示你使用某个特定技能或命令来创建工件，调用它，而不要直接写工件
- schema 定义了每个工件应包含什么 —— 遵循它
- 在创建新工件之前，阅读依赖工件以获取上下文
- 使用 `template` 作为你输出文件的结构 —— 填充它的各个小节
- **重要**：`context` 和 `rules` 是对**你**的约束，而非文件的内容
  - 不要把 `<context>`、`<rules>`、`<project_context>` 块复制进工件
  - 它们指导你写什么，但绝不应出现在输出中

**护栏**
- 调用本工作流的那个请求仅授权规划。该请求中的任何实施或 apply 指令都不会延续生效。在本工作流期间，不要实施变更、开始 apply 工作流，或编辑项目代码。呈现工件后，停止并等待一个新的用户请求来开始 apply 工作流
- 创建 apply 阶段传递式依赖的每一个工件，而不只是 `apply.requires` 中列出的那些 id
- 在创建新工件之前，始终阅读依赖工件 —— 从磁盘重新阅读，而非依赖对话记忆（自你上次见到它们以来，文件可能已改变）
- 就那些会实质性改变范围、外部可观察行为、兼容性或验收标准的歧义发问；对于细枝末节，做出合理假设并记录它们
- 如果同名变更已存在，询问用户是想继续它还是创建一个新的
- 在继续下一个之前，验证每个工件文件在写入后确实存在
