# RunAll_TestHarness.ps1
# Orchestrated test wrapper for NITRO-KB
# Logs structured JSON lines + console summary; supports forced-backoff simulation

# Version History
# v1.0.0 Updated 8/21/25 - initial harness

param(
    [switch]$ForceBackoff,
    [int]$MaxKB = 80,
    [string]$LogPath = ".\Output\NITRO_KB_Test_$((Get-Date).ToString('yyyyMMdd_HHmm')).jsonl"
)

if (-not (Test-Path ".\Output")) { New-Item -Path ".\Output" -ItemType Directory | Out-Null }

$Summary = [ordered]@{
    StartTime      = (Get-Date)
    ForceBackoff   = $ForceBackoff.IsPresent
    MaxKB          = $MaxKB
    Steps          = @()
    Retries        = 0
    Backoffs       = 0
    Skips          = 0
    Errors         = 0
}

function Write-JsonLog { param([object]$o)
    $o | ConvertTo-Json -Depth 6 -Compress | Out-File -FilePath $LogPath -Append -Encoding utf8
}

$env:NITROKB_FORCE_BACKOFF = $(if($ForceBackoff){"1"} else {"0"})

# Detect if RunAll_v2.ps1 supports -MaxKB
$ra = Join-Path (Get-Location) "RunAll_v2.ps1"
$hasMaxKb = $false
if (Test-Path $ra) {
    try {
        $cmd = Get-Command $ra -ErrorAction Stop
        $hasMaxKb = $cmd.Parameters.ContainsKey('MaxKB')
    } catch {}
}

try {
    $stepStart = Get-Date
    if ($hasMaxKb) {
        .\RunAll_v2.ps1 -MaxKB $MaxKB -Verbose 4>&1 | Tee-Object -Variable raw | Out-Null
    } else {
        .\RunAll_v2.ps1 -Verbose 4>&1 | Tee-Object -Variable raw | Out-Null
    }
    $Summary.Steps += [ordered]@{ Step="RunAll_v2"; DurationSec=((Get-Date)-$stepStart).TotalSeconds; Lines=$raw.Count }
}
catch {
    $Summary.Errors++
    Write-Warning "Harness caught exception: $($_.Exception.Message)"
}

$Summary.EndTime = Get-Date
Write-JsonLog $Summary

Write-Host ""
Write-Host "==== Harness Summary ===="
$Summary.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0,-12} {1}" -f $_.Name, $_.Value } | Write-Host
Write-Host "Log: $LogPath"
