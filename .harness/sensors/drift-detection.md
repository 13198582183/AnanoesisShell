# Drift Detection Sensor — Spec 漂移检测

> 变更级 Spec 漂移检查，在 /opsx:apply 完成后、归档前触发。

## 触发时机
每次 /opsx:apply <change-name> 所有任务完成后、归档前必须执行本 Sensor。

## 检查流程
### Step 1 识别涉及的 Spec
读取 openspec/changes/<change-name>/ 下 specs，提取 ADDED / MODIFIED / REMOVED Requirements，
定位对应 openspec/specs/<module>/ 文件。

### Step 2 逐场景对照
对每个 Requirement 的每个 Scenario：提取 GIVEN / WHEN / THEN → 定位代码实现 → 判定：
对齐 / 漂移（代码与 spec 不一致）/ 缺失（无实现）。

### Step 3 输出偏差清单
以 Markdown 表格输出每个场景的对齐状态。

### Step 4 以代码为准更新 Spec
漂移 → 更新 spec 与代码一致（代码是真相源）；缺失 → 补实现或更新 spec 并标注原因；更新后重新对照。

### Step 5 确认无漂移
全部对齐后，在 tasks.md 底部记录检查时间与结果。

## 检查范围
| 检查项 | 说明 |
|--------|------|
| 接口路径 / 契约 | spec 定义的端点 / 接口与实现一致 |
| 数据结构 | spec 定义字段与实际数据结构一致 |
| 业务规则 | spec 的 THEN 条件与代码行为一致 |
| 错误处理 | spec 定义的错误码 / 状态与实现一致 |
| 边界条件 | spec 描述的边界行为与代码一致 |
