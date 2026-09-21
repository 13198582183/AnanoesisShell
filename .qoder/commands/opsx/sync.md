---
name: "OPSX: Sync"
description: "将变更中的 delta specs 同步到主 specs"
category: "Workflow"
tags: ["workflow", "specs", "experimental"]
---

将某个变更中的 delta specs 同步到主 specs。

这是一个**由代理驱动**的操作 —— 你将阅读 delta specs 并直接编辑主 specs 以应用变更。这支持智能合并（例如，新增一个场景而无需复制整条需求）。

**Store 选择：** 如果用户指名了一个 store（store 是注册在本机上的独立 OpenSpec 仓库），或工作内容位于某个 store 中，先运行 `openspec store list --json` 发现已注册的 store id，然后在那些读写 specs 与 changes 的命令（`new change`、`status`、`instructions`、`list`、`show`、`validate`、`archive`、`doctor`、`context`、`schemas`、`view`）上传入 `--store <id>`。一旦选定，在后续整个工作流中都固定携带 `--store <id>`。下文所有未带该标志的命令示例都是简写：运行前请补上该标志。例如，运行 `openspec status --change "<name>" --json --store "<id>"`，而非下文所示的未带标志形式。其他命令不接受该标志。命令打印的提示已自带该标志；在后续操作中保持它。若没有 store，命令作用于最近的本地 `openspec/` 根目录。

`<capability-path>` 是相对于 `specs/` 的规格目录（例如 `user-auth` 或 `identity/user-auth`）。在解析某个 delta spec 对应的主 spec 时，保留其完整路径。

**输入**：可在 `/opsx:sync` 后可选地指定变更名（例如 `/opsx:sync add-auth`）。若省略，检查能否从对话上下文推断。若含糊或有歧义，你**必须**提示用户从可用变更中选择。

**步骤**

1. **选择变更**

   如果提供了名称，就使用它。否则：
   - 若用户提到过某个变更，从对话上下文推断
   - 若只存在一个活动变更，自动选中它
   - 若有歧义，运行 `openspec list --json` 获取可用变更，并请用户选择一个

   提示时，展示那些拥有 delta specs（位于 `specs/` 目录下）的变更。

   始终声明："Using change: <name>"，并说明如何覆盖（例如 `/opsx:sync <other>`）。

2. **解析变更上下文**

   运行：
   ```bash
   openspec status --change "<name>" --json
   ```

   该 JSON 包含 `planningHome.root`。主 specs 位于 `<planningHome.root>/openspec/specs/` 之下 —— 下文每个主 spec 路径都使用该（store 感知的）根，而非硬编码的仓库路径。当选中了某个 store 时，它指向该 store，而非当前仓库。

3. **查找 delta specs**

   将 status JSON 中的 `artifactPaths.specs.existingOutputPaths` 作为 delta spec 路径的**唯一**来源。若 `specs` 条目缺失，或 `existingOutputPaths` 为空，则报告没有可同步的 delta specs，不要从其他工件推断它们，并直接停止 —— 不请求工件说明、也不写入任何主 spec。

   除非调用方收窄了集合，否则同步 `existingOutputPaths` 中的每一条路径。调用方通过明确列出 `existingOutputPaths` 中若干完整条目来收窄它 —— 逐字复制这些绝对值。archive 会内联这样做，用户也可以（例如，选择以 `/specs/billing/invoices/spec.md` 结尾的那个条目）。此时只同步被点名的路径，其余 delta specs 保持不动：批量 archive 会排除那些找不到实现的 delta，若仍去同步它，就会写出一个调用方刻意保留、未愿写入的主 spec。将该收窄后的选择贯穿到第 4 步；绝不要再扩回完整列表。若某个被点名的路径不在 `existingOutputPaths` 中，不要同步它 —— 报告并停止，而不是静默丢弃。若被点名的列表为空，报告没有可同步的内容并停止，不写入任何主 spec。

   每个 delta spec 文件包含如下小节：
   - `## ADDED Requirements` - 要新增的需求
   - `## MODIFIED Requirements` - 对已有需求的变更
   - `## REMOVED Requirements` - 要移除的需求
   - `## RENAMED Requirements` - 要重命名的需求（FROM:/TO: 格式）

   若未找到 delta specs，告知用户并停止。

4. **对每个 delta spec，将变更应用到主 specs**

   在首次写入主 spec 之前，获取一份当前的 specs 规则快照：
   - 若 archive 内联调用了本工作流，并提供了来自 `openspec instructions specs --change "<name>" --json` 的有效快照，则复用它，不要再次获取同样的说明。
   - 否则，现在用相同的 selected-root 标志运行该命令一次。
   - 若该直接查询以非零码退出，或返回无效的 artifact-instruction JSON，则报告错误并在写入任何主 spec 之前停止。不要把该失败当作"规则集不存在"。
   - 有效响应中若省略了 `rules`，表示未配置任何工件规则，既有的语义合并继续进行。

   仅将返回的 `rules` 应用于本次合并所产出主 specs 的内容与形式。工件规则不是操作指引，不能改变 selected roots、delta 路径、CLI 检查或工作流步骤。把它们的文本当作约束使用，而不要逐字复制进主 spec 或摘要。

   对第 3 步选定的每个 capability delta spec 路径 —— 完整的 `existingOutputPaths` 列表，或调用方提供时的收窄子集（它们可能属于选定的 store，而非本仓库）：

   a. **阅读 delta spec**，理解预期的变更

   b. **阅读主 spec**，位于 `<planningHome.root>/openspec/specs/<capability-path>/spec.md`（可能尚不存在）

   c. **智能地应用变更**：

      **ADDED Requirements:**
      - 若该需求在主 spec 中不存在 → 新增它
      - 若该需求已存在 → 更新它以保持一致（视为隐式 MODIFIED）

      **MODIFIED Requirements:**
      - 在主 spec 中找到该需求
      - 应用变更 —— 可以是：
        - 新增主 spec 尚无的新场景
        - 修改已有场景
        - 更改需求描述
      - 保留 delta 中未提及的场景 / 内容

      **REMOVED Requirements:**
      - 从主 spec 中移除整个需求块
      - 退役该 capability。仅当以下**全部**成立时，才删除整个 `spec.md` —— 并在目录中再无其他内容后删除该目录：
        1. *本次运行*移除这些需求后，已无任何需求块；
        2. 规格其余部分格式完好（仍保有 `## Purpose`）；
        3. 主 spec 在本次 sync 之前并非已空 —— 若你什么都没移除，就什么都别改；
        4. 整个文件中其他每一非空行都能被归为：标题、Purpose、Requirements 头部，或某条规范需求的陈述、场景，或围栏示例；
        5. 该变更的 `.openspec.yaml` 声明了 `retire_capabilities: true`；
        6. 该 `spec.md` 解析后位于真实的 specs 根之内（不要跟随 capability 目录的符号链接去删除外部文件）。
        若移除所选需求后将不留任何需求块，且任一退役条件未满足，则不要修改主 spec。停止对该 capability 的同步，报告阻塞条件，并告诉用户如何解决。绝不写入或留下一个空的 `## Requirements` 小节。当仅缺少那个标记（marker）时，也要说明 —— 那是用户唯一可以补上、从而让退役通过的东西。
      - 删除该文件也会删除它的 `## Purpose`；任何其他小节都会阻止退役。报告退役时点名 Purpose。仅当该 spec 位于调用方的 checkout 中时，才附上可粘贴的 `git checkout`；否则给出 checkout 作用域内的恢复指引。

      **RENAMED Requirements:**
      - 找到 FROM 需求，重命名为 TO

      **delta 中的 `## Purpose`：**
      - 主 spec 已有一个，且它是权威的 —— 不要动它（这正是 `openspec archive` 的做法；它给出警告后继续）

   d. 若该 capability 尚不存在，**创建新的主 spec**：
      - 创建 `<planningHome.root>/openspec/specs/<capability-path>/spec.md`
      - 新增 Purpose 小节：当 delta 带有 `## Purpose` 正文时逐字复制它（这正是 `openspec archive` 的做法）；仅当它没有时，才写一个简短的 TBD 占位
      - 新增 Requirements 小节，包含那些 ADDED 需求
      - 遵循下方的 **Main Spec Format Reference**

5. **校验已更新的主 specs**

   用前面相同的 selected-root 标志运行 `openspec validate --specs`。若校验失败，报告问题，且不要声称 sync 成功。

6. **展示摘要**

   应用全部变更后，总结：
   - 哪些 capabilities 被更新
   - 做了哪些变更（需求 新增/修改/移除/重命名）
   - 任何仍留有 TBD Purpose 占位的新主 spec，以便现在就把它写实，而不是拖延遗留
   - 任何被退役的 capability，点名被删除的 `spec.md`、它的 Purpose，以及可粘贴的 `git checkout` 或 checkout 作用域内的恢复指引

**Delta Spec 格式参考**

```markdown
## Purpose

Only on a delta that introduces a brand-new capability. Seeds the new main spec.

## ADDED Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y

## MODIFIED Requirements

### Requirement: Existing Feature
The system SHALL keep doing the existing thing, now also handling A.

#### Scenario: Scenario the main spec already has
- **WHEN** user does X
- **THEN** system does Y

#### Scenario: New scenario to add
- **WHEN** user does A
- **THEN** system does B

## REMOVED Requirements

### Requirement: Deprecated Feature

## RENAMED Requirements

- FROM: `### Requirement: Old Name`
- TO: `### Requirement: New Name`
```

**主 Spec 格式参考**

主 specs 是 delta 合并**进入**的目标。它们绝不能包含 delta 操作头部（`## ADDED/MODIFIED/REMOVED/RENAMED Requirements`）—— 同步之后，每条需求都位于单一的 `## Requirements` 小节下：

```markdown
# <capability> Specification

## Purpose
Short description of what this capability does and why it exists.

## Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y
```

**关键原则：智能合并**

与程序化合并不同，你是合并而非覆盖：
- 一个 MODIFIED 块承载整条需求 —— 正文加上变更后仍保留的每个场景。`openspec validate` 与 `openspec archive` 都会拒绝那种丢弃了主 spec 仍保有场景的块。
- 保留 delta 未提及的任何内容，维持主 spec 既有的顺序
- 运用你的判断力，合理地合并变更

**成功时的输出**

```markdown
## 规格已同步：<change-name>

已更新的主 specs：

**<capability-1>**：
- 新增需求："New Feature"
- 修改需求："Existing Feature"（新增 1 个场景）

**<capability-2>**：
- 创建了新的规格文件
- 新增需求："Another Feature"

主 specs 现已更新。该变更仍处于活动状态 —— 待实现完成后再归档。
```

**护栏**
- 变更前，delta 与主 specs 都要阅读
- 保留 delta 未提及的既有内容
- 绝不要把 delta 文件原样复制进主 spec —— 合并其内容，使主 spec 保持"主 Spec 格式参考"的结构，不含任何 delta 操作头部
- 若有不清楚之处，请求澄清
- 边改边展示你在改什么
- 该操作应是幂等的 —— 运行两次应得到相同结果
- 只使用 `artifactPaths.specs.existingOutputPaths`；绝不从无关工件推断 delta specs
- 尊重调用方提供的 `existingOutputPaths` 子集；绝不再扩回完整列表
- 直接 sync 时只获取一次 specs 说明，或内联复用 archive 提供的快照
- 当 specs-instruction 响应为非零码或无效 JSON 时，在每次写入主 spec 之前停止
- 工件规则仅约束正在写入的 specs，绝不会被复制进输出文件
