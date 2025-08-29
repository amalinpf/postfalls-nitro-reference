# v2.1.4 2025-08-20 — Added polite pacing via Respect-Rate
# 10_FindKB.ps1
# v2.1.3 2025-08-19 — Heartbeat logs + capped retries during find, guarded imports

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$VerbosePreference     = 'SilentlyContinue'  # flip to 'Continue' if you want -Verbose spam

# Imports
. "$PSScriptRoot\00_Config.ps1"
if (-not (Get-Module -Name 01_Helpers)) {
    Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force -DisableNameChecking
}

# Optional cookie session
$Session = $null
if ($UseCookieAuth -and $CookieString) {
    $Session = New-CCWebSession -CookieString $CookieString -Domains $CookieDomains
}

# Output seed file
$seedOut = Join-Path $OutputRoot $SeedListName

# Base URL
$base = 'https://www.crowcanyon.help/article'

# Heartbeat / timing
$sw = [System.Diagnostics.Stopwatch]::StartNew()
function _tick($msg) {
    Write-Host ("[FindKB {0,7} ms] {1}" -f $sw.ElapsedMilliseconds, $msg) -ForegroundColor DarkCyan
}

# Collect results
$found = [System.Collections.Generic.List[string]]::new()

# Be snappier during FIND: don’t back off forever here
$FindMaxRetries = [Math]::Min($MaxRetries, 2)

for ($i = $StartId; $i -le $EndId; $i++) {
    $u = "$base/$i/"
    _tick "GET $u"
    try {
Respect-Rate
        $resp = Invoke-Web-Smart -Url $u -WebSession $Session `
                 -MaxRetries $FindMaxRetries -MinBackoffMs $MinBackoffMs -MaxBackoffMs $MaxBackoffMs
        _tick "RECV $u status=$($resp.StatusCode) bytes=$($resp.Content.Length)"
        if ($resp.StatusCode -eq 200 -and $resp.Content -match '<title>') {
            $found.Add((Normalize-Url $u))
            Write-Host "OK $u"
        }
    } catch {
        _tick "ERR  $u : $($_.Exception.Message)"
        # Continue scanning; a single failure shouldn't stall the entire find pass
    }
}

# Write unique, sorted list to seed file
$uniq = $found | Sort-Object -Unique
$uniq | Set-Content -Encoding UTF8 $seedOut
Write-Host ("Seeded {0} URLs -> {1}" -f $uniq.Count, $seedOut) -ForegroundColor Green
