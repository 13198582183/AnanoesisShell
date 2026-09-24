# Tasks: add-desktop-client

## 1. 前置核验与脚手架

- [x] 1.1 复核选型时效性：`npm view electron version` 记录选定大版本；核对 Temurin JRE 17 win32-x64 发行页（许可 GPLv2+CE 再分发条款）与 Electron 官方支持系统页，结论写进本变更目录 `spike-notes.md`；若 Electron 最新版本线出现与 D1 冲突的事实，先回改 design 再继续
- [x] 1.2 在 frontend 子仓库创建 `desktop/` 目录骨架（package.json devDependencies：electron 精确 pin、electron-builder、typescript；tsconfig；`.gitignore` 产物目录），验证 `npm install` 成功且不动前端主应用依赖树
- [x] 1.3 后端新增配置开关骨架：检测 `ANANOESIS_LAUNCHER_TOKEN` env 存在与否暴露 `desktopGuardEnabled` Bean（先只含开关判定与 health show-details 联动），集成测试断言"无 env 守卫关、有 env 守卫开"两种上下文均可启动

## 2. 后端桌面守卫（TDD：先 RED 后 GREEN）

- [x] 2.1 写守卫 RED 集成测试：守卫开启态下 ①无 Cookie 的 REST 请求 401、②无 Cookie 的 WS 握手被拒、③带合法 tk 引导根路径后换发 HttpOnly Cookie 且后续请求通行、④错误 tk 不换发票且响应不含 Cookie 头、⑤`/actuator/health` 无票 GET 可读且 `show-details` 为 never、组件细节不出现；确认全部失败为断言失败而非环境错误
- [x] 2.2 实现 `com.ananoesis.shell.desktop` 包：tk 引导（常数时间比较、302 去除 URL 票据）、内存态票仓（进程重启失效）、Servlet Filter 统一校验 REST + WS 握手拦截器；2.1 全部转绿
- [x] 2.3 RED→GREEN：`POST /internal/shutdown` 持票返回 202 且触发 context.close 走 graceful；无票 401；非 POST 405；测试用独立子上下文或 mock 生命周期避免真杀测试 JVM
- [x] 2.4 tk 掩码防线：新增日志回归测试，把访问含 `?tk=` 的引导请求走一遍，断言日志与 `desktop.log` 不出现 token 明文（对齐既有 HTTP 日志三道防线）
- [x] 2.5 默认回环绑定：`application.yml` 增 `server.address: 127.0.0.1`（开发形态经 vite proxy 不受影响），全量后端回归 772+ 用例保持绿；本机验证从另一网卡 IP 连接 18080 被拒

## 3. 后端静态托管与同源加载

- [x] 3.1 RED→GREEN：桌面 profile 下配置 `spring.web.resources.static-locations` 指向外置 dist 目录；集成测试断言 GET `/` 返回 index.html、GET 任意非 API 路径回退 index.html、`/api/**`、`/ws/**`、`/actuator/**`、`/internal/**` 不被回退遮蔽（用真实契约端点各抽一个证明 404/401 语义不变）
- [x] 3.2 前端生产构建适配：确认 axios/fetch 与 WS 地址在生产态为同源相对路径（如有绝对 dev 地址残留则修正），index.html 加 CSP meta（default-src 'self'，xterm 所需 style/worker 例外逐项最小放开）；`npm run build` 与前端 288 全量测试绿，vue-tsc 0 错误

## 4. Electron 壳与进程监管

- [x] 4.1 主进程启动链路：单实例锁（第二实例聚焦已有窗口后退出）、生成 256bit token、探测空闲端口、以 `runtime/bin/java.exe -jar` + env 注入 spawn 后端、轮询 health 至 UP、`loadURL(http://127.0.0.1:port/?tk=...)`；`will-navigate` 拦截窗口内跳外站、`contextIsolation:true` + `nodeIntegration:false` + 空 preload 占位；开发态冒烟：指向本机已构建 dist/jar 手动起壳，窗口出现工作区且功能可用
- [x] 4.2 退出与崩溃监管：shuttingDown 标志 + `POST /internal/shutdown` → 等待 exit（上限 10s）→ 超时 kill 兜底；非预期 exit 走 1s/2s/4s 退避重启、10 分钟窗口 3 次止损后经 splash 错误面板明示故障（含日志路径，见 4.3）；冒烟验证：任务管理器强杀 java 进程后壳自动恢复、正常退出后无孤儿 java.exe
- [x] 4.3 启动画面（splash）：无边框居中深色本地静态页（应用名 AnanoesisShell + 宗旨「让 Linux 运维不再困难」+ 署名「李仔文 / liziwen」，CSS 轻量动效），`app.whenReady` 即展示；后端就绪且主窗 loadURL 成功后淡出退场；启动失败/止损时切换为错误面板（原因摘要＋重试/退出）而非弹独立对话框；冒烟验证三种时机下画面行为正确且无白屏瞬间（对应 spec「启动画面与开发者署名」与 design D10）
- [x] 4.4 启动失败路径回归：故意以损坏 jar 路径启动壳，验证错误由 splash 错误面板承载（含可读原因与重试/退出，同 4.3 机制），不出现白屏或静默退出

## 5. 构建组装与安装包
- [x] 5.1 主仓库 `scripts/build-desktop.ps1`（PowerShell 5.1 兼容、UTF-8 BOM、检查 `$LASTEXITCODE`）：vite build → mvnw package → JRE 下载缓存 → 复制 jar/dist/runtime 到 electron-builder 资源位 → 产出 NSIS Setup.exe 到 `frontend/desktop/dist-release/`；本机全脚本跑通一次
- [x] 5.2 electron-builder NSIS 配置：perMachine、默认 Program Files、`oneClick:false`+`allowToChangeInstallationDirectory:true`、应用图标与产品名（win.icon=assets/icon.png，产物 exe 图标提取取证）；发行者身份落位（**v26 实证修正**：`win.company`/`nsis.publisherName` 字段已删，CompanyName/ARP Publisher 统一取 package.json `author.name`="李仔文 liziwen"，exe 属性 COMPANY=[李仔文 liziwen] 复验通过）；签名钩子仅在证书环境变量存在时启用 `win.certificateFile`，无证书时构建日志显式打印"未签名"；产出安装包体积记录进 spike-notes（实测 193.0MB，预计 ~250MB 量级内）
- [x] 5.3 安装/卸载行为验证：本机安装到自选路径 → 首启完成 spec「自选路径安装后首启」场景（既有 ~/.ananoesis 数据原样可见）→ Windows「应用和功能」与 exe 属性可见发行者 liziwen（李仔文）（spec「安装后发行者可见」）→ 卸载不动用户数据目录 → 重装数据仍在。【实证：用户真机安装 F:\ananoesisShell 自选路径、升级安装数据保留、COMPANY=[李仔文 liziwen] 取证通过；升级桌面图标不更新另修 installer.nsh（known-issues #30）】

## 6. 集成验收（浏览器/实机门禁）

- [x] 6.1 安装包级端到端冒烟（本机 Windows 11）：装→起→连 test-vm(192.168.237.129)→Shell 模式交互终端→Agent 提问→审批执行与取消→SFTP 面板→退出无孤儿进程；过程截图与结论写入变更目录。【实证：用户真机全流程实测通过（含 AI 配色/内网 think 渲染/图标），截图见 .tmp-probe bugd-*/bugf-*/verify-*】
- [x] 6.2 授权对抗走查：客户端运行期间用普通浏览器直开 `http://127.0.0.1:{port}/`（应 401 空页）、curl 直连 REST 与 WS 握手（应拒）、`netstat` 证明监听仅 127.0.0.1；结论记录。【实证：guard-walkthrough-report.txt——捆绑 java PID 仅听 127.0.0.1:56415（非回环 0）、无票 REST/根路径皆 401、WS 握手拒、本机 7 个网卡 IP 直连全部 REFUSED、health 无票 200 且仅 {"status":"UP"} 无组件细节】
- [x] 6.3 兼容矩阵：干净 Windows 11 虚拟机过发布矩阵第 1、2、5 条（无 Java/Node 首启、SSH/中文/Ctrl-C/resize、中文空格路径与 DPI）；Windows 10 若有环境同测，无环境则在发布物明确标注 Win10 未验证（spec「未验证项不外宣」）。【环境受限如实降级：无干净虚拟机，以开发机+用户实机实测覆盖第 1、2、5 条主体；Release 页仅宣称已实机验证范围，标明「Windows 10 与干净虚拟机未验证」，不外宣全矩阵通过】
- [x] 6.4 工作流第 6 节全量验证命令逐条执行并记录退出码：type-check / vitest / vite build / mvn test / verify-structure / openspec validate --all --strict 全绿。【2026-09-24：FE_EXIT=0（type-check+vitest+vite build）、BE_EXIT=0 BUILD SUCCESS（mvn test 全量）、VS_EXIT=0、openspec validate --all --strict 10 passed 0 failed；日志 .tmp-probe/gate-be.log / gate-fe.log】

## 7. 发布与口径回写

- [ ] 7.1 主仓库 `gh release create v0.1.0`：挂载 Setup.exe，Release 说明中文载明安装要求、发行者署名 liziwen（李仔文）、未经 Authenticode 签名的如实声明与 SmartScreen 处理指引、自动更新未实现、实际已验证的系统范围；网页端确认可下载
- [x] 7.2 修订兼容口径：`AGENTS.md` 技术栈行（+Electron 壳与捆绑 JRE 17、兼容目标 Win10/11）、`.qoder/rules/platform-compatibility.md` 移除 Win7 承诺并保留"实机验证才可以说通过"条款；文档描述与 Release 页一致。【2026-09-24 完成：两文件均已修订，Electron 版本线按实际 pin 44.4.5 记载】
- [x] 7.3 `.qoder/known-issues.md` 回写本变更实证发现的坑（含 Windows destroy 不触发 shutdown hook、health show-details 泄露面等，四要素齐全）。【实施期间持续回写：#27 安装器占用 EPERM、#28 CSP 剥 xterm 动态样式致配色丢失、#29 内网模型 think 开闭标签内联 content 双载体、#30 keepShortcuts+图标缓存致桌面快捷方式不更新】
- [ ] 7.4 三仓提交推送闭环：backend → frontend → 主仓库（指针+工件），记录 commit hash；随后 /opsx:archive 同步 `desktop-client` 主 spec
