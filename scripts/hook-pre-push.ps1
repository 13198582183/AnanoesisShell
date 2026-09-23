# hook-pre-push.ps1 — pre-push coverage gate
# Detects change scope; if backend changed, runs mvn verify (with JaCoCo check)
# JaCoCo check branch coverage >= threshold -> pass; no backend changes -> skip

$ErrorActionPreference = 'Stop'

$root = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Host "[pre-push] Cannot get git root, skipping" -ForegroundColor Yellow
    exit 0
}

# pre-push receives remote ref args; fall back to last commit diff
$remoteRef = $args[1]
$localRef = $args[3]

if ($remoteRef -and $localRef) {
    $changedFiles = git diff --name-only $remoteRef $localRef 2>$null
} else {
    # Fallback: check last commit changes
    $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null
}

if ([string]::IsNullOrWhiteSpace($changedFiles)) {
    Write-Host "[pre-push] No changes, skipping coverage check" -ForegroundColor Yellow
    exit 0
}

$hasBackend = $false
foreach ($file in ($changedFiles -split "`n")) {
    if ($file -match '^backend/') { $hasBackend = $true; break }
}

if (-not $hasBackend) {
    Write-Host "[pre-push] No backend changes, skipping coverage check" -ForegroundColor Yellow
    exit 0
}

Write-Host "[pre-push] Backend changes detected, running mvn verify (with JaCoCo coverage check)..." -ForegroundColor Cyan

$pomPath = Join-Path $root 'backend\pom.xml'
& powershell -NoProfile -Command "& '$root\backend\mvnw.cmd' -f '$pomPath' -B verify 2>&1"
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host "`n[pre-push] mvn verify FAILED (test failure or coverage below threshold). Push blocked." -ForegroundColor Red
    exit 1
}

Write-Host "`n[pre-push] mvn verify passed, coverage OK" -ForegroundColor Green
exit 0
