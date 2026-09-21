# 已知问题记录（Known Issues）

> 本文档记录项目开发过程中遇到的 bug、错误和解决方案，避免后续重复踩坑。
> **开发前必读**；**解决问题后必须补充**（症状 / 根本原因 / 解决方案 / 预防措施）。

---

## 记录规范

每条问题按以下结构记录（编号递增）：

    ## N. <一句话标题>
    **发现时间**: YYYY-MM-DD
    **影响范围**: <受影响的模块/流程>
    **症状**: <可观测到的错误表现>
    **根本原因**: <为什么会发生>
    **解决方案**: <如何修复，含命令/代码>
    **预防措施**: <如何避免再次发生>

---

## 1. PowerShell 管道向原生程序传输中文被 GBK 重编码破坏

**发现时间**: 2026-09-20
**影响范围**: Windows PowerShell 5.1 下，任何把含中文的文本经管道 `|` 喂给原生程序（git / 数据库客户端 / cli）的场景
**症状**: `Get-Content file.txt -Raw -Encoding UTF8 | some-native-exe` 执行后，中文变成 `??` 或乱码；但直接读取文件内容显示正常
**根本原因**: PowerShell 把管道数据传给原生程序时，会按 `$OutputEncoding` / 控制台 OEM 代码页（中文系统为 GBK/936）重新编码字节流，UTF-8 的多字节中文被破坏。
**解决方案**:
- 会话内临时切换 UTF-8：`chcp 65001; $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8`
- 避免用管道把中文喂给原生程序，改用「文件中转 + 程序自身读取」或参数传递
- 永久修复：Windows 设置开启 “Beta: 使用 Unicode UTF-8 提供全球语言支持”，或改用 Windows Terminal
**预防措施**: Windows 下处理含非 ASCII 数据时，一律用文件重定向（`< file` / `--result-file` / `-o file`），禁止用 PowerShell 管道 `|` 直接喂给原生客户端；处理后抽查中文字段。

---

## 2. git submodule / worktree 分支不同步导致提交丢失或指针错乱

**发现时间**: 2026-09-20
**影响范围**: 主控仓库 + `frontend/`、`backend/` 子模块的并行开发
**症状**: 主仓库切到 feature 分支后，子模块仍停留在 `main`（或 detached HEAD）；子模块内的提交未推送，主仓库记录的 submodule 指针指向本地未推送的 commit，他人 clone 后 `git submodule update` 失败
**根本原因**: `git submodule` 默认 checkout 固定 commit（detached HEAD），不跟随主仓库分支切换；worktree 也不会自动为子模块创建同名分支。
**解决方案**:
- 进入子模块开发前，显式创建/切换分支：`cd frontend; git checkout main; git pull; git checkout -b feature/<name>`
- 提交顺序：**先**在子模块内 commit + push，**再**回主仓库 `git add frontend backend; git commit`（记录已推送的指针）
- 推送顺序：先推子模块，后推主仓库
**预防措施**: 遵循 `.qoder/rules/workflow-conventions.md` 的子模块 / worktree 约束；每次操作后用 `git submodule status` 确认指针前缀非 `+`/`-`（`+` 表示子模块 checkout 与主仓库记录不一致，`-` 表示未初始化）。

---

## 3. Windows PowerShell 5.1 运行含中文的 UTF-8 无 BOM 脚本时解析报错

**发现时间**: 2026-09-21
**影响范围**: 仓库内所有含中文字符串 / 注释的 `.ps1` 脚本（如 `scripts/verify-structure.ps1`、`scripts/init-workspace.ps1`）在 Windows PowerShell 5.1 下的执行
**症状**: 脚本无法运行，抛出 `MissingEndCurlyBrace`（“缺少右 `}`”）或 “Try 语句缺少其自己的 Catch 或 Finally 块”，报错行号指向结构完整的 `try {` / `exit 0`，肉眼检查括号并无缺失
**根本原因**: Windows PowerShell 5.1 读取**无 BOM** 的 `.ps1` 时按系统 ANSI 代码页（中文系统为 GBK/936）解码；UTF-8 编码的中文字节被 GBK 误读，而 GBK 尾字节范围包含 `0x7B`/`0x7D`（即 `{`/`}`），会在字符串字面量中注入**游离的花括号**，破坏 `try{}` / `foreach{}` 的括号平衡，导致解析器中途报错。
**解决方案**:
- 将脚本重存为 **UTF-8 with BOM**，PowerShell 5.1 会据 BOM 正确识别为 UTF-8：
  `$c = Get-Content -Raw -Encoding UTF8 $p; [IO.File]::WriteAllText($p, $c, (New-Object Text.UTF8Encoding $true))`
- 或改用 PowerShell 7+（`pwsh`，默认按 UTF-8 读取脚本，无需 BOM）
**预防措施**: 本项目所有含中文的 `.ps1` 一律以 **UTF-8 with BOM** 保存；用会剥离 BOM 的编辑器 / 工具改写脚本后，必须重新执行 `scripts\verify-structure.ps1` 确认可解析（观察 `$LASTEXITCODE` 是否为 `0`，而非仅看中文是否乱码）。

---

**最后更新**: 2026-09-21
**维护者**: AI Agent + 开发团队
