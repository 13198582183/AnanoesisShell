---
trigger: always_on
alwaysApply: true
---

# 平台范围与 Windows 兼容规范

## 1. 产品范围（用户明确要求）
- 远端连接与运维只做 Linux 服务器；不开发 Windows Server、macOS 等其他远端系统能力，不增加 RDP 等非 Linux SSH 产品范围。
- 最终客户端仅安装在 Windows，兼容目标为 Windows 7、Windows 10、Windows 11；不开发 Linux/macOS 客户端安装包。
- 当前交付形态仍是本地 Web MVP（Vue3 前端 + Spring Boot 后端），桌面壳、安装器、运行时捆绑与升级尚未实现。
- “目标支持”“厂商支持”“实机验证通过”必须分别记录；当前开发机运行正常不能证明三种 Windows 均兼容。
- Windows 版本/补丁下限、x86/x64/ARM64 架构范围尚未裁定，不能擅自把需求缩小成仅 Win10/11 或仅 x64；在桌面兼容性变更中确认矩阵。

## 2. 已核实的选型约束
- 当前后端编译基线为 Java 17，本机 JDK 21 编译不能推导目标系统可运行；必须核实选定 JRE 发行版、具体版本、许可及原生依赖的操作系统支持。
- Electron 22 是最后支持 Windows 7 的大版本；Electron 23 及以后不支持 Windows 7。旧内核停止维护，不能为兼容而无说明地固定旧版，不能宣称安全更新仍受保障。
- Windows 7 的 Edge/WebView2 兼容线止于 109；采用 WebView2 的壳也必须验证 SDK、Rust/工具链及安装器，不能仅凭旧 Runtime 能启动就认定兼容完成。
- Oracle JDK 17 当前认证列表没有 Windows 7；这不是“所有 Java 17 发行版都绝对无法运行”的证明。不得擅自降到 Java 8/11 绕过问题（会改变 Spring Boot 3 的运行基线）。
- 可评估现代 Windows 主线与 Win7 兼容线分离，但仅是候选方向；未通过 OpenSpec 可行性验证与风险确认前，不锁定 Electron/Tauri/JRE 发行版。

## 3. 开发与打包约束
- 远端命令使用 Linux 路径与 Linux shell 语义，本地文件使用 Windows 路径 API；不得用本地路径分隔符处理远端路径。
- 生产客户端应可在未安装 Java/Node 的机器离线安装和启动；构建机工具链与客户机运行时分开，不要求用户安装开发依赖。
- 捆绑后端须管理就绪探测、端口冲突、单实例、退出与崩溃清理；不能靠硬杀所有 Java 进程收尾，也不能用固定等待代替健康检查。
- 本地 API/WS 需要 loopback 绑定、受控 Origin 与本地调用授权方案；当前开发 Origin 配置不等于生产鉴权，不能把本机命令执行端口默认暴露到局域网。
- 数据与日志放用户可写目录，不写 Program Files；升级保留数据，卸载删除用户数据需明确选择，凭据迁机须处理 OS 密钥绑定。
- 中文/空格用户名和路径必须正确处理；PowerShell 5.1 命令不使用 `&&`，失败后检查 `$LASTEXITCODE`；含中文 `.ps1` 保存 UTF-8 BOM，避免默认 ANSI 解码。
- 固定最低浏览器内核后检查 JS/CSS/Web API 兼容性；Vite 构建成功不代表运行时 API 已自动 polyfill，更不代表 Windows 原生依赖可用。

## 4. 发布验收矩阵
每个承诺支持的系统版本与架构均须在干净虚拟机或实机完成并记录：
1. 无预装 Java/Node、离线安装、首次启动、普通用户权限运行、退出无孤儿后端。
2. SSH 密码/私钥/passphrase、指纹确认、中文终端、Ctrl-C、top/vim、窗口 resize 与断线恢复。
3. 模型 HTTPS/TLS 请求、流式响应、审批批准/拒绝/超时，网络中断时状态可恢复且不重放命令。
4. OS 密钥库、SQLite JDBC/JNA 等原生依赖、数据库迁移、重启后数据/凭据可用。
5. 中文/空格路径、DPI 缩放、键盘导航、剪贴板和长文本滚动。
6. 升级/失败恢复、安装包签名、运行时许可与漏洞风险；未测项目明确标为未验证，不对外承诺支持。

## 5. 官方依据
以下页面用于核验支持边界；选型与发布时重新核查，不能把本次查询当永久有效承诺：
- Electron Windows 7 停止支持说明：https://www.electronjs.org/blog/windows-7-to-8-1-deprecation-notice
- Microsoft Edge 支持系统：https://learn.microsoft.com/en-us/deployedge/microsoft-edge-supported-operating-systems
- WebView2 平台说明：https://learn.microsoft.com/en-us/microsoft-edge/webview2/
- Oracle JDK 17 认证平台：https://www.oracle.com/java/technologies/javase/products-doc-jdk17certconfig.html
