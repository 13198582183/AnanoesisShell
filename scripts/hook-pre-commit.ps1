# hook-pre-commit.ps1 — pre-commit fast gate
# Detects staged changes scope, runs minimal validation per scope
# backend changes -> mvn compile -q (compile only, no tests)
# frontend changes -> type-check + test

$ErrorActionPreference = 'Stop'

$root = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Host "[pre-commit] Cannot get git root, skipping" -ForegroundColor Yellow
    exit 0
}

# Get staged file list (excluding deletions)
$changedFiles = git diff --cached --name-only --diff-filter=d
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($changedFiles)) {
    Write-Host "[pre-commit] No staged changes, skipping" -ForegroundColor Yellow
    exit 0
}

$hasBackend = $false
$hasFrontend = $false

foreach ($file in ($changedFiles -split "`n")) {
    if ($file -match '^backend/') { $hasBackend = $true }
    if ($file -match '^frontend/') { $hasFrontend = $true }
}

if (-not $hasBackend -and -not $hasFrontend) {
    Write-Host "[pre-commit] No backend/frontend changes, skipping" -ForegroundColor Yellow
    exit 0
}

$failed = $false

if ($hasBackend) {
    Write-Host "[pre-commit] Backend changes detected, running compile check..." -ForegroundColor Cyan
    $pomPath = Join-Path $root 'backend\pom.xml'
    & powershell -NoProfile -Command "& '$root\backend\mvnw.cmd' -f '$pomPath' -B compile -q 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[pre-commit] Backend compile FAILED!" -ForegroundColor Red
        $failed = $true
    } else {
        Write-Host "[pre-commit] Backend compile OK" -ForegroundColor Green
    }
}

if ($hasFrontend) {
    Write-Host "[pre-commit] Frontend changes detected, running type-check + test..." -ForegroundColor Cyan
    $fePath = Join-Path $root 'frontend'

    # type-check
    & npm --prefix $fePath run type-check 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[pre-commit] Frontend type-check FAILED!" -ForegroundColor Red
        $failed = $true
    } else {
        Write-Host "[pre-commit] Frontend type-check OK" -ForegroundColor Green
    }

    # test (only if type-check passed)
    if (-not $failed) {
        & npm --prefix $fePath run test 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[pre-commit] Frontend test FAILED!" -ForegroundColor Red
            $failed = $true
        } else {
            Write-Host "[pre-commit] Frontend test OK" -ForegroundColor Green
        }
    }
}

if ($failed) {
    Write-Host "`n[pre-commit] Gate FAILED. Commit blocked." -ForegroundColor Red
    exit 1
}

Write-Host "`n[pre-commit] All checks passed" -ForegroundColor Green
exit 0
