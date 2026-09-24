# Proposal: add-desktop-client

## Why

两阶段部署策略的阶段 1（Web 形式跑通 SSH/AI/审批/传输核心）已闭环；用户明确要求进入阶段 2——把整套前后端打包为在用户本地电脑运行的 Windows 桌面客户端（.exe 安装包），并作为首个 GitHub Release 发布，供用户直接下载安装。当前 Web 形态还存在隐藏缺口：后端默认绑定所有网卡、无任何本机调用授权、优雅停止通道在 Windows 上实际不生效，这些必须在桌面化时一并关闭。

## What Changes

- 新增 Electron 桌面壳（用户选定方向，兼容线已修订为仅 Windows 10/11）：主进程负责单实例锁、后端子进程的启动/就绪探测/崩溃退避重启/退出收尾，窗口加载本机后端服务的页面。
- 后端桌面化改造：
  - 显式绑定 `127.0.0.1`（loopback），杜绝命令执行端口暴露到局域网；
  - 托管前端构建产物（同源加载，页面 origin 即后端 origin）；
  - 启动令牌授权：壳生成随机 token 经环境变量注入后端，页面首次加载验票换发 HttpOnly 会话 Cookie，REST 与三条 WS 通道均校验此票——本机其他进程/浏览器页面不得再驱动该端口；
  - 新增受令牌保护的内部 shutdown 端点，补上 Windows 下 `Process.destroy()` 不触发 shutdown hook 导致的优雅停止真空。
- 捆绑 Temurin JRE 17（win32-x64）随安装包分发，用户机器无需安装 Java/Node。
- 新增启动画面（splash）：启动即展示应用名 AnanoesisShell、宗旨文案「让 Linux 运维不再困难」与开发者署名「李仔文 / liziwen」，就绪后自动退场，失败时兜底错误态。
- 发行者身份：安装包与程序元数据（exe 属性、「应用和功能」）发行者统一署名 liziwen（李仔文）；构建脚本预留 Authenticode 签名钩子（检测到证书环境变量即启用），本版本无证书不承诺签名、Release 如实标注。
- electron-builder 产出 NSIS 安装包：默认安装于 C 盘 Program Files、允许用户自选安装路径；用户数据仍留在 `%USERPROFILE%\.ananoesis` 与 Electron userData，不写安装目录。
- 构建与发布流水线（本机脚本级，不建 CI 服务）：一键组装「前端 dist → 后端 jar → JRE → Electron 壳 → Setup.exe」，并将产物以 `v0.1.0` 首个 Release 推送到主控 GitHub 仓库供直接下载。
- **BREAKING**（承诺修订，非运行时破坏）：客户端兼容目标由 Windows 7/10/11 修订为仅 Windows 10/11；Win7 支持经用户决定放弃。同步修订 `AGENTS.md` 与 `.qoder/rules/platform-compatibility.md` 中的 Win7 口径。
- 非目标（显式出局，后续变更另议）：自动更新、Authenticode 代码签名与 SmartScreen 信誉建立（本变更仅落发行者署名与签名钩子，见 design D11）、Linux/macOS 客户端、Win7、CI 云端构建。

## Capabilities

### New Capabilities

- `desktop-client`：桌面客户端的进程生命周期（启动/就绪/单实例/崩溃重启/退出收尾）、启动画面与开发者署名、本机服务绑定与调用授权、安装包形态与安装路径行为、Release 交付与 Win10/11 兼容验收。

### Modified Capabilities

- 无。现有九个 capability 均不含服务绑定地址、Origin/授权豁免或安装形态方面的需求条文，本变更的新行为全部落在 `desktop-client` 内，不改动既有需求。

## Impact

- **frontend 子仓库**：新增 `desktop/` 目录（Electron 主进程 + preload + electron-builder 配置，TypeScript）；前端生产构建 base 路径与 CSP 适配；API/WS 地址逻辑从"dev 代理"扩展为"同源相对"。
- **backend 子仓库**：新增桌面化配置与过滤器（loopback 绑定、静态托管 + SPA 回退、launcher token 授权、内部 shutdown 端点）；shutdown/授权端点属本机进程管理面，不进 `contract/openapi.yaml` 业务契约（在 design.md 记录豁免理由与守护方式）。
- **主仓库**：构建组装脚本、发布流程文档；`AGENTS.md` 技术栈行增补 Electron 与 JRE 捆绑，`.qoder/rules/platform-compatibility.md` 移除 Win7 承诺；`openspec/specs/desktop-client/` 归档落地。
- **依赖与体积**：引入 Electron/electron-builder 开发依赖与 Temurin JRE 分发物（安装包含 JRE + jar + 壳，量级预计 200MB 上下）；GitHub Release 单文件 2GB 上限内。
- **安全面**：DPAPI/java-keyring 凭据模型不动；新增的授权层是本机端口从"裸奔"到"持票"的净收紧。
- **验证门禁**：工作流第 6 节验证命令不变；新增安装包级冒烟（装→起→连测试机→审批→卸）与 Win10/11 干净虚拟机走查（发布矩阵第 1–3、5 条）。
