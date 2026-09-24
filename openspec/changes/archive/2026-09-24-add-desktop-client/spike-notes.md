# Spike Notes：选型时效复核（任务 1.1，2026-09-23）

## Electron
- npm 当前稳定版：**44.4.5**（`npm view electron version` 实测输出）；electron-builder 当前版：**26.15.3**。
- 官方 breaking-changes 页（electronjs.org/docs/latest/breaking-changes）明示：**Electron v23.0.0 起要求 Windows 10 或更高**——与本变更兼容目标（仅 Win10/11）完全一致，与 design D1 无冲突。
- 结论：锁定 `electron@44.4.5` 精确版本（package.json 不带 `^`），升级属后续独立变更。

## Temurin JRE 17（win32-x64）
- Adoptium API 实测（`/v3/assets/latest/17/hotspot?os=windows&architecture=x64&image_type=jre`）存在 JRE 形态包：
  - `OpenJDK17U-jre_x64_windows_hotspot_17.0.20.1+1.zip`，约 **41.7 MiB**（43,780,109 B）；
  - SHA-256：`bc21a93923103cdaac93ee337b0ae4365e739fde36df823dd456bc67c8a9d352`（构建脚本下载后必须校验此值）。
- 许可：**Eclipse Temurin = GPLv2+Classpath Exception**（endoflife.date 与 Adoptium 官网一致确认），Adoptium 条款允许再分发未修改二进制——随安装包捆绑合规。
- 预留有界优化（不在本变更实施）：用 `jlink` 按后端实际模块集裁出更小的运行时；首期直接捆全量 JRE，简单可靠。

## 风险登记
- Electron 44 内置 Chromium 版本较新，xterm.js（当前 @xterm 依赖）需在生产构建后于壳内回归渲染/输入法（列入 6.1 冒烟路径）。
- 国内网络拉取 electron 二进制可能超时：构建脚本与本机构建允许经 `ELECTRON_MIRROR` 环境变量指向镜像，不写入仓库默认配置。

## 安装包体积记录（任务 5.2，2026-09-24 实测）
- `AnanoesisShell-Setup-0.1.0.exe`：**193.0 MB**（含 Electron 44 壳 + 全量 Temurin JRE 17 + app.jar 65.5MB + 前端 dist），在预计 ~250MB 量级内、远低于 2GB 异常线；win-unpacked 主 exe 234.7MB。
- 图标已嵌入（win.icon=assets/icon.png）：构建日志 icons-bundle 生效、无 “application icon is not set” 告警，ExtractAssociatedIcon 取证为自定义终端图标；exe CompanyName=[李仔文 liziwen]。
