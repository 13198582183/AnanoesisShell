<#
.SYNOPSIS
    校验 AnanoesisShell AI Workspace 结构完整性（Harness 反馈控制门禁）。
.DESCRIPTION
    检查主控仓库必备目录/文件、子模块、OpenSpec、vendored 技能、Harness、治理文档
    是否齐备。任一缺失即以非零码退出，可用于提交前 / CI 门禁。
.NOTES
    用法：.\scripts\verify-structure.ps1 [-Root <仓库根目录>]
    退出码：0 = 全部通过；1 = 存在缺失项。
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$requiredPaths = @(
    '.gitmodules', '.gitignore', '.gitattributes',
    'AGENTS.md', 'CLAUDE.md', 'README.md', 'LICENSE',
    'frontend', 'backend',
    'openspec', 'openspec\specs', 'openspec\changes',
    '.qoder\commands\opsx',
    '.qoder\skills', '.qoder\skills\LICENSE', '.qoder\skills\README.md',
    '.qoder\agents',
    '.qoder\rules\workflow-conventions.md', '.qoder\rules\coding-standards.md',
    '.qoder\known-issues.md',
    '.harness\README.md',
    '.harness\guides\workflow.md', '.harness\guides\coding-standards.md',
    '.harness\sensors\quality.md', '.harness\sensors\drift-detection.md'
)

$requiredSkills = @(
    'brainstorming', 'writing-plans', 'executing-plans', 'test-driven-development',
    'systematic-debugging', 'verification-before-completion',
    'requesting-code-review', 'receiving-code-review'
)

$missing = @()

Write-Host "== 校验必备路径 ==" -ForegroundColor Cyan
foreach ($p in $requiredPaths) {
    if (Test-Path (Join-Path $Root $p)) {
        Write-Host "  [OK]   $p" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] $p" -ForegroundColor Red
        $missing += $p
    }
}

Write-Host "== 校验 vendored 技能（须含 SKILL.md）==" -ForegroundColor Cyan
foreach ($s in $requiredSkills) {
    $rel = ".qoder\skills\$s\SKILL.md"
    if (Test-Path (Join-Path $Root $rel)) {
        Write-Host "  [OK]   $s" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] $rel" -ForegroundColor Red
        $missing += $rel
    }
}

Write-Host "== 校验子模块初始化状态 ==" -ForegroundColor Cyan
Push-Location $Root
try {
    $subStatus = & git submodule status
    if ($LASTEXITCODE -ne 0 -or -not $subStatus) {
        Write-Host "  [MISS] git submodule status 失败或无子模块（exit $LASTEXITCODE）" -ForegroundColor Red
        $missing += 'submodules'
    } else {
        foreach ($line in $subStatus) {
            if ($line -match '^-') {
                Write-Host "  [MISS] 子模块未初始化: $line" -ForegroundColor Red
                $missing += 'submodule-uninit'
            } elseif ($line -match '^\+') {
                Write-Host "  [WARN] 子模块指针与记录不一致: $line" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK]   $line" -ForegroundColor Green
            }
        }
    }
} finally {
    Pop-Location
}

Write-Host ""
if ($missing.Count -gt 0) {
    Write-Host "结构校验失败：缺失 $($missing.Count) 项" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "结构校验通过：所有必备项齐备 [OK]" -ForegroundColor Green
exit 0
