# RunAll_v2.ps1
# v2.1.3 2025-08-19 — Guarded module import, auth banner, step logs, and full 10–70 flow

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'  # avoid flaky built-in progress UI

# 0) Load config + helpers (guarded to prevent duplicate warnings)
. "$PSScriptRoot\00_Config.ps1"
if (-not (Get-Module -Name 01_Helpers)) {
    Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force -DisableNameChecking
}

# 1) Show which auth mode we're in
Show-AuthBanner

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$ScriptName
    )
    $path = Join-Path $PSScriptRoot $ScriptName
    if (Test-Path $path) {
        Write-Host "[Step] $Label..." -ForegroundColor Cyan
        & $path
        if ($LASTEXITCODE) { throw "$ScriptName failed with exit code $LASTEXITCODE" }
    } else {
        Write-Host "[Skip] $ScriptName not found; skipping '$Label'." -ForegroundColor DarkYellow
    }
}

# 2) Network / incremental (should be no-op if nothing changed)
Invoke-Step -Label "Find KB URLs"         -ScriptName '10_FindKB.ps1'
Invoke-Step -Label "Download first-level"  -ScriptName '20_Download_FirstLevel.ps1'
Invoke-Step -Label "Extract links"         -ScriptName '30_Extract_Links.ps1'
Invoke-Step -Label "Download linked"       -ScriptName '40_Download_Linked.ps1'

# 3) Offline/local build (always runs; fast)
Invoke-Step -Label "Rewrite links"         -ScriptName '50_Rewrite_Links.ps1'
Invoke-Step -Label "Build index"           -ScriptName '60_Build_Index.ps1'
Invoke-Step -Label "Bundle metadata"       -ScriptName '70_Bundle_Metadata.ps1'

Write-Host "[Done] Build outputs complete." -ForegroundColor Green
