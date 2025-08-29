# Switch-Mode.ps1
# Runs the KB pipeline in both modes (Relative & Absolute) by temporarily
# updating 00_Config.ps1, invoking RunAll.ps1, and restoring the original config.

# Version History
# v1.0.0 Updated 8/19/25 - Initial version: build Relative then Absolute; restore config on exit

[CmdletBinding()]
param(
  [switch]$RelativeOnly,
  [switch]$AbsoluteOnly,
  [string]$AbsoluteRoot # Optional override for Absolute run; falls back to current 00_Config.ps1 value
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$cfgPath = Join-Path $here '00_Config.ps1'
$runAll  = Join-Path $here 'RunAll.ps1'

if (-not (Test-Path $cfgPath)) { throw "Missing 00_Config.ps1 in $here" }
if (-not (Test-Path $runAll))  { throw "Missing RunAll.ps1 in $here" }

# Read current config (raw) and stash for restore
$original = Get-Content $cfgPath -Raw -ErrorAction Stop

function Set-LinkModeInConfig {
  param(
    [Parameter(Mandatory)] [ValidateSet('Relative','Absolute')] [string]$Mode,
    [string]$AbsRoot
  )
  $content = Get-Content $cfgPath -Raw

  # 1) Flip $LinkMode
  $content = [regex]::Replace(
    $content,
    '^\s*\$LinkMode\s*=\s*''[^'']*''',
    "$" + "LinkMode = '$Mode'",
    'IgnoreCase, Multiline'
  )

  # 2) Optionally set $AbsoluteRoot (only if provided OR Mode is Absolute and it's currently empty)
  if ($Mode -eq 'Absolute') {
    if (-not $AbsRoot) {
      # Try to read existing AbsoluteRoot from the current file
      $m = [regex]::Match($content, '^\s*\$AbsoluteRoot\s*=\s*''([^'']*)''', 'IgnoreCase, Multiline')
      if ($m.Success) {
        $AbsRoot = $m.Groups[1].Value
      }
    }
    if (-not $AbsRoot) {
      throw "Absolute mode requires -AbsoluteRoot or a non-empty `$AbsoluteRoot in 00_Config.ps1."
    }
    $content = [regex]::Replace(
      $content,
      '^\s*\$AbsoluteRoot\s*=\s*''[^'']*''',
      "$" + "AbsoluteRoot = '$AbsRoot'",
      'IgnoreCase, Multiline'
    )
  }

  # Write back
  Set-Content -Encoding UTF8 -Path $cfgPath -Value $content
}

function Run-Pipeline {
  Write-Host "==> Running pipeline: $((Get-Content $cfgPath -Raw | Select-String -Pattern '^\s*\$LinkMode\s*=\s*''([^'']*)''' -AllMatches -CaseSensitive).Matches.Groups[1].Value)" -ForegroundColor Cyan
  & $runAll
}

# Determine which modes to run
$modes = @()
if ($RelativeOnly -and $AbsoluteOnly) {
  throw "Pick only one of -RelativeOnly or -AbsoluteOnly (or neither to run both)."
} elseif ($RelativeOnly) {
  $modes = @('Relative')
} elseif ($AbsoluteOnly) {
  $modes = @('Absolute')
} else {
  $modes = @('Relative','Absolute')
}

try {
  foreach ($m in $modes) {
    Write-Host "`n--- Preparing $m build ---" -ForegroundColor Yellow
    if ($m -eq 'Absolute') {
      Set-LinkModeInConfig -Mode 'Absolute' -AbsRoot $AbsoluteRoot
    } else {
      Set-LinkModeInConfig -Mode 'Relative'
    }
    Run-Pipeline
    Write-Host "--- Completed $m build ---`n" -ForegroundColor Green
  }
}
finally {
  # Always restore the original config
  Set-Content -Encoding UTF8 -Path $cfgPath -Value $original
  Write-Host "Config restored to original state." -ForegroundColor DarkGray
}

Write-Host "Done. Check ./HTML_Relative and/or ./HTML_Absolute." -ForegroundColor Green
