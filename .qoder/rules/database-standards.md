---
trigger: always_on
alwaysApply: true
---

# SQLite 与持久化规范

> 适用于迁移、实体、Mapper、设置、会话与审计持久化。依据 V1/V2 迁移（`V2__session_workspace_and_transfers.sql` 引入多会话工作区与传输表）、数据源配置、EntityIds、Timestamps 和现有服务提取；不要把旧注释当作真实运行行为。

## 1. 数据源与迁移
- 单机本地存储使用 SQLite + MyBatis-Plus + Flyway，不擅自引入独立数据库服务。数据放可配置的用户目录，当前默认 `${user.home}/.ananoesis/data.db`；测试使用临时目录，禁止操作用户真实数据库。
- 保持 WAL、每连接 `foreign_keys=on`、busy timeout 和有界连接池；当前默认 busy timeout 为 10000ms、池上限为 4。SQLite 仍是单写者，增大线程/连接数不能消除写争用。
- 当前 `synchronous=NORMAL` 是性能/耐久性折中，不承诺断电零丢失。涉及备份、恢复、迁移时必须设计一致性和失败恢复验证。
- 所有 DDL/初始化数据通过 `src/main/resources/db/migration/V<版本>__<描述>.sql`；已应用迁移不回写，后续结构变更追加新版本，保留校验和。
- 连接级 PRAGMA 留在数据源配置，不能把它当一次迁移后永久生效。禁止通过关闭外键或自动 baseline 掩盖不一致的数据库。
- 同时验证新库初始化和旧版本升级；破坏性迁移先给备份/恢复步骤。SQLite 表重建须保留索引、约束、数据与引用关系，不承诺 Flyway 能自动反向回滚。

## 2. 命名与类型
- 表/列使用 snake_case；Java 属性 camelCase，显式下划线映射。约束与索引命名延续 `ix_` / `ux_`。
- 对外资源主键使用 TEXT canonical UUID（8-4-4-4-12），由 `EntityIds.newUuid()` 或 UUID 分配入口生成；`settings.setting_key` 是业务键例外。
- V1 的“32 位 UUID”注释与 MyBatis `ASSIGN_UUID` 兜底不是接口规范；不得让对外服务依赖无连字符 ID，再由 `UUID.fromString` 读回。
- 布尔值使用 INTEGER 0/1 并保留 CHECK；枚举使用 TEXT + CHECK，字段可空性与默认值均须明确，不以空字符串替代 NULL。
- 当前时间持久化为不带时区的 ISO-8601 TEXT / LocalDateTime；API 时间为 OffsetDateTime，经 `Timestamps` 按系统时区转换。禁止混入 SQLite UTC CURRENT_TIMESTAMP 或各处手写时区换算。
- 当前时间方案依赖单机时区不变；跨时区导入、用户改时区、同步需求须单独迁移，不能宣称已有 UTC 存储。
- JSON TEXT 使用 ObjectMapper 等统一序列化器，禁止手工拼 JSON；需要查询/索引的关键字段保持独立列。

## 3. 关系与数据归属
- 当前七张业务表：`hosts`、`credentials`、`sessions`、`ai_conversations`、`ai_messages`、`approvals`、`settings`。
- 当前模型配置是 settings 中的非敏感 JSON，API Key 在 credentials；没有独立 model_configs 表。后续拆表须迁移，不能凭 API 名臆造实体表。
- 沿用业务删除语义：主机的 session 可级联；对话/审批的历史引用按 SET NULL 保留；消息随所属对话级联。修改删除语义必须先评估审计保留需求。
- credentials 的多态归属由 `(owner_type, owner_id, credential_type)` 唯一约束保证；它没有普通宿主外键，宿主删除时由服务在事务内显式清理。
- 同会话消息 seq 唯一且有序；并发追加必须保留顺序及冲突策略。不可把“查询最大 seq 后加一”当作天然无竞争。

## 4. 更新、事务与查询
- `NOT_NULL` 是当前写入策略；“不修改字段”与“显式清空”必须区分，清空 nullable 列使用明确的 Mapper/UpdateWrapper，不能依赖 updateById 忽略 null 后假装清空成功。
- 多表配置/凭据一致性变更使用服务层短事务；审批等待、模型调用、SSH 网络 I/O 不跨入写事务。
- 参数绑定为默认路径；禁止把未经校验的搜索、排序、字段名或用户字符串拼 SQL。动态列名用白名单。
- 当前未注册 MyBatis-Plus 分页拦截器；不要只传 Page 并假设生效。沿用校验后的有界 LIMIT/OFFSET，稳定排序追加唯一键，count/list 分用独立 wrapper。
- 对话、审计、会话查询必须分页或有明确上限；根据实际过滤与排序列建立索引，不以无上限全表加载作为常态。
- 设置项有类型、默认值、范围及读取入口；“已写进 settings”不等于运行时生效，更不等于已有 UI。新增设置要验证保存→读取→业务行为闭环。

## 5. 敏感数据与验证
- 密码、私钥、passphrase、API Key 的持久化唯一入口为 credentials.ciphertext；settings、hosts 等不能旁路保存明文，密钥不与密文放在同一库。
- 命令、工具参数、stdout/stderr、聊天和审计也是潜在秘密载体；后续改动必须处理相关泄露路径。当前审计缺少内容脱敏，不得以凭据表已加密推导整库安全。
- 备份 WAL 数据库须使用一致性备份方案，不能直接复制仍在写入的 data.db 并假设完整；加密凭据迁机还涉及 OS 密钥绑定，不能仅拷贝库文件承诺可用。
- 验证至少覆盖迁移、每连接外键、唯一/CHECK 约束、NULL 清空、删除语义、UUID/时间转换、分页上限及凭据不明文；现有测试锚点为 SqliteSchemaMigrationTest、FlywayMigrationPurityTest、MapperCrudTest 与 API 集成测试。
