# install-hooks.ps1 — one-click git hook installer for all 3 repos
# main repo: core.hooksPath = .githooks
# frontend/ and backend/ submodules: core.hooksPath = ../.githooks

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot | Split-Path -Parent

function Set-HookPath {
    param(
        [string]$RepoPath,
        [string]$HookPath,
        [string]$Label
    )
    Push-Location $RepoPath
    try {
        Write-Host "Configuring $Label hook path..." -ForegroundColor Cyan
        git config core.hooksPath $HookPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  $Label git config failed!" -ForegroundColor Red
            return $false
        }
        $val = git config core.hooksPath
        Write-Host "  $Label core.hooksPath = $val OK" -ForegroundColor Green
        return $true
    } finally {
        Pop-Location
    }
}

# main repo
$ok = Set-HookPath -RepoPath $root -HookPath '.githooks' -Label 'main'
if (-not $ok) { exit 1 }

# frontend submodule
$fePath = Join-Path $root 'frontend'
if (Test-Path (Join-Path $fePath '.git')) {
    $ok = Set-HookPath -RepoPath $fePath -HookPath '../.githooks' -Label 'frontend'
    if (-not $ok) { exit 1 }
} else {
    Write-Host "  frontend/ is not a git repo, skipped" -ForegroundColor Yellow
}

# backend submodule
$bePath = Join-Path $root 'backend'
if (Test-Path (Join-Path $bePath '.git')) {
    $ok = Set-HookPath -RepoPath $bePath -HookPath '../.githooks' -Label 'backend'
    if (-not $ok) { exit 1 }
} else {
    Write-Host "  backend/ is not a git repo, skipped" -ForegroundColor Yellow
}

Write-Host "`nHook installation complete! All repos point to .githooks/" -ForegroundColor Green
