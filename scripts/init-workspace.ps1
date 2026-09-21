<#
.SYNOPSIS
    幂等初始化 AnanoesisShell AI Workspace（子模块 + OpenSpec + vendored 技能）。
.DESCRIPTION
    在新克隆或结构缺失时运行，按序执行；已存在的部分自动跳过，可重复运行：
      1) 初始化并拉取 git submodule（frontend / backend）
      2) 若 openspec/ 不存在则运行 openspec init（原生 Qoder /opsx 命令）
      3) 若 .qoder/skills/<skill>/SKILL.md 缺失则从全局插件缓存复制 Superpowers 技能
      4) 最后调用 verify-structure.ps1 做结构门禁校验
.NOTES
    用法：.\scripts\init-workspace.ps1 [-Root <仓库根>] [-SuperpowersVersion <版本>]
    依赖：git；Node 22 + @fission-ai/openspec；全局 superpowers@<版本> 插件缓存。
    升级 Superpowers：改 -SuperpowersVersion 默认值并同步 .qoder/skills/README.md。
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$SuperpowersVersion = '5.1.0'
)

Push-Location $Root
try {
    Write-Host "[1/4] 初始化 git submodule ..." -ForegroundColor Cyan
    & git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule update 失败（exit $LASTEXITCODE）" }

    Write-Host "[2/4] 检查 OpenSpec ..." -ForegroundColor Cyan
    if (Test-Path (Join-Path $Root 'openspec')) {
        Write-Host "  openspec/ 已存在，跳过 init" -ForegroundColor Yellow
    } else {
        & openspec init --tools qoder --no-animation --force --no-copilot-cloud
        if ($LASTEXITCODE -ne 0) { throw "openspec init 失败（exit $LASTEXITCODE）" }
    }

    Write-Host "[3/4] 检查 vendored Superpowers 技能 ..." -ForegroundColor Cyan
    $skillsDst = Join-Path $Root '.qoder\skills'
    $skillsSrc = Join-Path $env:USERPROFILE ".qoder\plugins\cache\qoder-marketplace\superpowers\$SuperpowersVersion"
    if (-not (Test-Path $skillsSrc)) {
        throw "未找到 Superpowers 插件缓存：$skillsSrc（请确认全局已安装 superpowers@$SuperpowersVersion）"
    }
    $skills = @(
        'brainstorming', 'writing-plans', 'executing-plans', 'test-driven-development',
        'systematic-debugging', 'verification-before-completion',
        'requesting-code-review', 'receiving-code-review'
    )
    New-Item -ItemType Directory -Force -Path $skillsDst -ErrorAction Stop | Out-Null
    foreach ($s in $skills) {
        $dst = Join-Path $skillsDst $s
        if (Test-Path (Join-Path $dst 'SKILL.md')) {
            Write-Host "  跳过已存在技能：$s" -ForegroundColor Yellow
        } else {
            Copy-Item -Recurse -Force -ErrorAction Stop (Join-Path $skillsSrc "skills\$s") $dst
            Write-Host "  复制技能：$s" -ForegroundColor Green
        }
    }
    if (-not (Test-Path (Join-Path $skillsDst 'LICENSE'))) {
        Copy-Item -Force -ErrorAction Stop (Join-Path $skillsSrc 'LICENSE') (Join-Path $skillsDst 'LICENSE')
    }

    Write-Host "[4/4] 运行结构校验 ..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'verify-structure.ps1') -Root $Root
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
