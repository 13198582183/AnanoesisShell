# 凭据存储规格

## Purpose

提供对敏感凭据（SSH 密码、私钥及其 passphrase、大模型 api key）的安全存储能力，确保凭据不以明文落库、不硬编码于代码或配置文件，并受操作系统级密钥保护，仅在必要时刻于内存中解密使用。

## Requirements

### Requirement: 凭据加密存储

系统 SHALL 在持久化任何敏感凭据前对其进行加密，数据库中 MUST NOT 存储明文凭据。

#### Scenario: 保存 SSH 密码

- **WHEN** 用户为某服务器配置保存密码
- **THEN** 系统仅存储该密码的密文，明文不出现在持久化数据中

#### Scenario: 保存私钥

- **WHEN** 用户保存 SSH 私钥（含 passphrase）
- **THEN** 系统以密文形式存储私钥与 passphrase

### Requirement: 主密钥由操作系统密钥库保护

系统 SHALL 将用于加解密凭据的主密钥托管于操作系统密钥库，而非硬编码或明文配置；在密钥库不可用时 MUST 明确报错，不得静默降级为明文存储。

#### Scenario: 正常获取主密钥

- **WHEN** 系统需要加解密凭据且操作系统密钥库可用
- **THEN** 系统从密钥库取得主密钥并完成加解密操作

#### Scenario: 密钥库不可用

- **WHEN** 操作系统密钥库不可用
- **THEN** 系统拒绝以明文存储凭据，并向用户报告"凭据保护不可用"

### Requirement: API Key 不硬编码

系统 SHALL 仅通过用户设置项接收大模型 api key，MUST NOT 在源代码、构建产物或默认配置文件中内置任何 api key。

#### Scenario: 用户配置 api key

- **WHEN** 用户在设置项中填写 api key 并保存
- **THEN** 系统以密文存储该 api key，且不将其写入任何代码或明文配置

#### Scenario: 未配置 api key 即使用 AI

- **WHEN** 用户尚未配置 api key 即尝试使用 AI 功能
- **THEN** 系统提示"请先在设置中配置模型 api key"，而非使用任何内置默认值

### Requirement: 凭据的按需解密使用

系统 SHALL 仅在建立连接或调用模型等必要时刻于内存中解密凭据，使用后 MUST NOT 将明文凭据写入日志、审计记录或错误信息。

#### Scenario: 连接时使用凭据

- **WHEN** 系统发起 SSH 连接需要密码或私钥
- **THEN** 系统在内存中解密并使用凭据，且不在任何日志中记录其明文
