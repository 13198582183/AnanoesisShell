# AnanoesisShell

AnanoesisShell is an AI-powered remote terminal. Users don't need to think about commands — the AI automatically handles Linux operations.

> 让 Linux 运维不再困难 —— AI 驱动的远程终端：连接 Linux 服务器，用自然语言完成运维操作，命令执行前人工审批，终端/SFTP/AI 面板同屏协作。

## 下载（Windows 桌面客户端）

| 项 | 值 |
|------|------|
| 安装包 | [AnanoesisShell-Setup-0.1.0.exe](https://github.com/13198582183/AnanoesisShell/releases/tag/v0.1.0)（GitHub Release，约 193 MB） |
| 兼容目标 | Windows 10 / 11（x64）；无需预装 Java / Node（捆绑 Temurin JRE 17） |
| 发行者 | 李仔文 liziwen |
| 签名状态 | **未经 Authenticode 签名**，首次运行可能出现 SmartScreen 警告，点「更多信息 → 仍要运行」即可 |

功能：SSH 终端（密码/私钥）、AI Agent 问答与命令审批执行、SFTP 文件传输与进度、多会话工作区。数据存于 `%USERPROFILE%\.ananoesis`，卸载不删除用户数据。

## 特性

- **AI 运维对话**：云端 OpenAI 兼容模型与内网模型（vLLM/MindIE 内联 think 标签已适配）双通道流式渲染，思考/回答分色展示
- **命令审批**：AI 生成的 shell 命令执行前需人工确认，支持拒绝与超时终止
- **真实终端**：xterm.js 全交互终端，中文/resize/Ctrl-C 对齐，断线自动恢复
- **SFTP**：文件浏览、上传下载与进度显示
- **本地授权**：桌面形态后端仅绑定 `127.0.0.1`，启动令牌换取会话 Cookie，局域网无法直连

## 架构（AI Workspace）

主控仓库（本仓库）+ 两个 `git submodule` 子仓库，前后端分离：

| 仓库 | 角色 |
|------|------|
| 主控仓库（本仓库） | 规格 / 约束门禁 / 多代理编排 / 文档 / 桌面构建脚本 |
| [`frontend/`](https://github.com/13198582183/AnanoesisShell-frontend) | Vue3 + TypeScript + Vite + Pinia + xterm.js；`desktop/` 为 Electron 壳 |
| [`backend/`](https://github.com/13198582183/AnanoesisShell-backend) | Java 17 + Spring Boot 3.5 + Spring AI 1.1 + sshj；SQLite(WAL) + Flyway |

桌面形态由 Electron 壳监管本机后端子进程，页面由后端同源托管（`http://127.0.0.1:{port}/`），安装器为 electron-builder NSIS。

## 开发（Web 形态）

```powershell
# 1. 克隆（含子模块）
git clone --recurse-submodules https://github.com/13198582183/AnanoesisShell.git
cd AnanoesisShell
git submodule update --init --recursive

# 2. 后端（JDK 17+）
cd backend; .\mvnw.cmd spring-boot:run    # http://localhost:18080

# 3. 前端（Node 20+）
cd ../frontend; npm install; npm run dev  # http://localhost:3000（vite proxy 到后端）
```

## 构建桌面安装包

```powershell
.\scripts\build-desktop.ps1
# 产物：frontend/desktop/dist-release/AnanoesisShell-Setup-<version>.exe
# 注意：构建前默认清空 ~/.ananoesis/data.db（零配置发布态）；调试可加 -SkipWipe
# 国内网络需镜像：ELECTRON_MIRROR / ELECTRON_BUILDER_BINARIES_MIRROR（脚本内已处理）
```

## 工程规范

本项目遵循 **Spec-Driven Development (SDD)**：

- **规格真相源**：`openspec/specs/`；变更走 `/opsx:propose → /opsx:apply → /opsx:archive`
- **约束门禁**：`.harness/guides/`（前馈）+ `.harness/sensors/`（反馈）
- **AI 代理技能**：`.qoder/skills/`（vendored Superpowers）
- **代理指南**：见 `AGENTS.md`；已知陷阱见 `.qoder/known-issues.md`
- **平台兼容口径**：见 `.qoder/rules/platform-compatibility.md`（Win7 承诺已移除，实机验证才可以说通过）

## 文档

- 设计规格：`docs/superpowers/specs/`
- 实施计划：`docs/superpowers/plans/`
- 桌面客户端变更实证：`openspec/changes/archive/` 内 `add-desktop-client`（spike-notes）

## 许可证

[MIT](./LICENSE)
