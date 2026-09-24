# Design: add-desktop-client

## Context

现状：前端 Vue3+Vite 只在 dev server 上跑（vite proxy 转发 REST/WS 到 18080），后端 Spring Boot fat jar 独立运行，`backend/src/main/resources` 无静态托管；`application.yml` 已预留 `shutdown: graceful` 与"阶段 2 壳"注释；WS Origin 默认最严同源（白名单当前只放 dev 源）；数据在 `%USERPROFILE%\.ananoesis`，凭据走 java-keyring(DPAPI)+AES-GCM；OpenAPI 生成接口只覆盖业务 API。动机与范围见 proposal.md - Why。

## Goals / Non-Goals

**Goals：**
- Web 形态的全部既有行为零回归（dev 工作流、既有测试不动语义）。
- 桌面形态下本机端口从"裸奔"升级为"仅回环 + 持票"，作为净收紧项落地。
- 安装包在本机一键组装、可卸载、产物可上 GitHub Release。

**Non-Goals：**
- 自动更新、增量升级通道；Authenticode 代码签名与 SmartScreen 信誉建立（依赖购买证书，本变更仅落发行者元数据与签名钩子，见 D11）。
- 系统托盘、多窗口、窗口状态记忆等桌面增强体验（后续变更再议）。
- ARM64 与 32 位 Windows；CI 云端构建机。

## Decisions

### D1 壳运行时：Electron（用户选定）
Win7 出局后 Electron 可跟随当前稳定大版本，自带 Chromium 保证 Win10/11 渲染一致，xterm.js canvas 渲染无内核收敛成本；主进程用 Node 生态 spawn/监管后端最顺。
**否决备选**：Tauri（Win 依赖 WebView2 分发策略、Rust 侧监管 Java 子进程样板更多）；jpackage+浏览器（无单实例/生命周期收编语义，"桌面应用"体验残缺）；JavaFX 内嵌（引入第三套框架与 WebView 许可问题）。
版本锁定策略：`package.json` 精确 pin major/minor，升级 Electron 属独立变更；选定当日以 `npm view electron version` 与官方发布页复核（规则第 5 节禁止引用过期结论）。

### D2 页面加载：后端同源托管，壳只当浏览器壳
壳 `BrowserWindow.loadURL("http://127.0.0.1:{port}/?tk={token}")`，前端 dist 由后端静态资源 handler 托管（`spring.web.resources.static-locations` 指向安装目录内旁挂的 dist 目录 + SPA 回退转发到 index.html，`/api/**`、`/ws/**` 除外）。
**WHY 同源而非 app:// 自定义协议**：同源之下 WS 现有"默认不配白名单=同源限定"的 CSWSH 防线原样生效、REST 零 CORS 配置、Cookie 授权自动随请求走；app:// 方案则要给 REST 开跨源凭据、给 WS 白名单加 scheme，安全面净增。代码注释里预留的"壳加白名单"路线主动作废，在 spec 场景「同源加载」钉住。
**否决备选**：dist 打进 jar（构建期跨仓复制产物、jar 职责混杂）；file:// 加载（WS/REST 变跨源且 origin 为 null，白名单形同虚设）。

### D3 本机授权：启动令牌 → 会话 Cookie 引导
- 壳每次启动生成 256bit 随机 token，经环境变量 `ANANOESIS_LAUNCHER_TOKEN` 注入后端子进程（不落盘、不进命令行——命令行对同机任意进程 `Get-CimInstance` 可见，env 只对该子进程及其监管者可见）。
- 后端检测到该 env 存在即启用桌面守卫（无 env = Web/dev 形态，守卫关闭，既有行为不动）。
- 引导：浏览器带 `?tk=` 首次访问根路径 → 校验通过（常数时间比较）→ 换发随机 session id 的 HttpOnly + SameOrigin Cookie（内存态，进程重启即失效），并重定向去掉 URL 中的 tk；此后 REST 与 WS 握手（浏览器同源自动携带 Cookie）统一过同一个 Servlet Filter。
- `/actuator/health`：壳需要无凭据探活，故桌面守卫下 health 仅放行 GET 且强制 `show-details: never`（现状 always 会把 SQLite 路径给任何探活者）；就绪判定只看 status=UP。
**否决备选**：每次请求带 Authorization 头（前端要区分形态注入、WS 握手头在浏览器不可设）；固定端口+本地回环即安全论（不满足规则"本地调用授权方案"，本机恶意页面仍CSWSH）。

### D4 停止通道：内部 shutdown 端点
`POST /internal/shutdown`（回环 + 桌面守卫票据强制），命中后先回 202，再在独立线程触发 `context.close()` 走既有 graceful（在途 WS/审批收尾），进程随 Spring Boot 退出。壳侧：调用 → 等待子进程 exit（上限 10s）→ 超时 `child_process` kill 兜底并记录。
**WHY 不用信号**：Windows 下 `Process.destroy()`/taskkill 不跑 JVM shutdown hook，graceful 配置形同虚设——这是 spec「不留孤儿」与优雅收尾两条的机制支点。
**契约豁免**：该端点与 tk 引导不属于业务 API，不进 `contract/openapi.yaml`（生成链会把它错误暴露为公共面）；以 `DesktopGuardTest` 钉住"仅回环、须持票、仅 POST"三重约束，TRACEABILITY.md 登记一条豁免注记。

### D5 崩溃重启：壳侧退避监管
子进程 `exit` 事件非预期（非壳主动关闭流程置位 shuttingDown 标志）→ 退避 1s/2s/4s 重启，10 分钟窗口内累计 3 次即止损，故障呈现交给 splash 错误面板（含日志路径 `~/.ananoesis/logs/desktop.log`——后端日志文件化在桌面 profile 下开启，见 D10）。重启成功后页面自动重新走 tk 引导（tk 不变、Cookie 随新会话重建）。

### D6 后端产物与 JRE：捆绑 Temurin JRE 17 win32-x64
`java -jar backend.jar` 由壳用安装目录内 `runtime/bin/java.exe` 拉起，版本与编译基线同代，不引入 21 变数。经 electron-builder `extraResources` 打包 JRE、jar、dist 三物。
**否决备选**：GraalVM native-image（sqlite-jdbc/JNA/sshj 的 AOT 兼容性未验证，风险整包吞下）；要求用户自装 JRE（违反"无 Java/Node 离线安装"规则）。JRE 发行版许可（Temurin GPLv2+CE）与再分发条款在 tasks 里列核验项。

### D7 安装包：electron-builder NSIS per-machine
`perMachine: true`（默认装 `C:\Program Files\AnanoesisShell`，UAC 提权符合用户预期）、`oneClick: false` + `allowToChangeInstallationDirectory: true`（自选路径向导）；用户数据全部留在 `%USERPROFILE%\.ananoesis` 与 Electron `userData`（%APPDATA%），安装目录只读。卸载器不触碰用户数据目录。安装图标等资产缺口用最简自制图占位，不引入设计债。

### D8 构建与发布：本机脚本一键组装
主仓库 `scripts/build-desktop.ps1`：`vite build` → `mvnw package` → 拉取/缓存 JRE → `electron-builder --win nsis` → 产物落 `desktop/dist-release/`。发布为人工动作：`gh release create v0.1.0 <Setup.exe> --generate-notes` 于主仓库执行，Release 说明按 spec 要求载明"未签名/无自动更新"。PowerShell 5.1 兼容（不用 `&&`、UTF-8 BOM）。

### D9 代码归属：`desktop/` 入 frontend 子仓库
Electron 主进程/preload/构建配置放 `frontend/desktop/`（共享 node 工具链与 lockfile，避免第三个 submodule 的闭环负担）；后端守卫/托管放 `backend` 新包 `com.ananoesis.shell.desktop`；组装脚本与发布文档放主仓库 `scripts/` 与 `docs/`。

### D10 启动画面：本地静态 splash 窗
壳在 `app.whenReady` 后立即创建无边框、不可调整大小、居中的深色启动画面窗（纯本地 HTML/CSS，不依赖后端——后端起不来时它还要承载错误态）。内容三要素：应用名 **AnanoesisShell**、宗旨文案「让 Linux 运维不再困难」、开发者署名「李仔文 / liziwen」；配色对齐主界面深色基线（#0d1117 底 / #c9d1d9 主文本 / #58a6ff 点缀），动效为 CSS 轻量透明度扫掠与进度指示点，不引入视频资产或 splash 原生库（YAGNI）。
生命周期：启动即出现 → 后端 health UP 且主窗口 `loadURL` 成功后淡出关闭并聚焦主窗 → 若启动失败/反复崩溃止损，则 splash 内容切换为错误面板（原因摘要＋"重试/退出"按钮），与 spec「启动失败画面兜底」对应。这替代 D5 止损弹框与启动失败提示等独立对话框方案——失败感知统一收敛到 splash 一个承载物，避免"闪一下弹个框"的割裂体验。

### D11 发行者身份与签名：元数据先行，真签名留钩子
electron-builder `win.company: "liziwen"`、`productName: "AnanoesisShell"`、NSIS `publisherName: "李仔文 (liziwen)"`，exe 右键属性 Company/ProductName 随之；splash 署名与「应用和功能」同源同值。Authenticode 需要付费证书，本版本不假称已签：构建脚本仅在检测到证书文件与口令环境变量时经 `win.certificateFile` 启用签名，否则跳过并在构建日志打印"未签名"——将来持证零配置改动即可签。
**WHY 不做自签名**：自签证书不被系统信任链接纳，SmartScreen 警告照旧甚至更糟；诚实路径是"署名可见＋未签名如实声明"。

## Risks / Trade-offs

- **无 Authenticode 签名** → 用户首下载遇 SmartScreen「未知发布者」警告（发行者元数据可显示 liziwen/李仔文，但消不掉警告）：Release 说明显式指引"仍要保留/运行"路径并如实声明未签名；将来购证凭 D11 钩子直接启用。
- **token 泄露面**：tk 短暂出现在窗口加载 URL → 后端访问日志必须对 `tk=` 查询参掩码；env 不进日志。既有日志三道防线复用。
- **graceful 兜底后仍有硬杀窗口**：极端情况（JVM 卡死被 kill）SQLite WAL 依赖崩溃恢复，`synchronous=NORMAL` 承诺不丢库最多丢末事务——与现状 Web 强杀等价，不新增劣化，验收含崩溃后重启数据可读场景。
- **Electron+JRE 体积 ~250MB**：GitHub Release 单文件 2GB 限内；下载体验不做优化（非目标）。
- **Win10 干净虚拟机缺备**：验收矩阵要求两系统实测；若本机仅能覆盖 Win11，按 spec「未验证项不外宣」在 Release 说明标注 Win10 未验证，不虚假承诺。
- **静态托管回退与业务路由冲突**：SPA 回退只放行 GET 且排除 `/api`、`/ws`、`/actuator`、`/internal`，用契约对齐测试 + 新增集成测试钉住不遮蔽既有端点。
- **守卫误伤 Web 形态**：守卫开关唯一取决于 `ANANOESIS_LAUNCHER_TOKEN` 是否存在，全量后端回归测试必须在守卫关闭态下跑（默认即如此），防止 dev/CI 语义漂移。

## Migration Plan

实施顺序即回滚顺序的反向：1) 后端桌面守卫+静态托管（TDD，Web 形态全回归绿）→ 2) 前端 CSP/base 适配 → 3) Electron 壳与监管 → 4) 组装脚本与安装包 → 5) 冒烟 + 兼容走查 → 6) 发布 Release + 文档/规则口径修订。任一步失败不影响 Web 形态继续使用；桌面产物独立分发，撤销 Release 即回滚用户面。

## Open Questions

- 托盘最小化与关闭窗口语义（现在：关窗=退出）——不影响 spec/任务拆分，留待后续体验变更。
