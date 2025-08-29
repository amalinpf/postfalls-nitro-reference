# RunAll.ps1
# Orchestrates modular steps to produce a portable KB bundle.

# Version History
# v1.1.0 Updated 8/19/25 - Rooted outputs; ready for SP or local

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00_Config.ps1"

Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force
Show-AuthBanner

$steps = @(
  '10_FindKB.ps1',
  '20_Download_FirstLevel.ps1',
  '30_Extract_Links.ps1',
  '40_Download_Linked.ps1',
  '50_Rewrite_Links.ps1',
  '60_Build_Index.ps1',
  '70_Bundle_Metadata.ps1'
)

foreach ($s in $steps) {
  Write-Host "==> $s" -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot $s)
  if ($LASTEXITCODE) { throw "$s failed with exit code $LASTEXITCODE" }
}
Write-Host "`nAll done." -ForegroundColor Green
