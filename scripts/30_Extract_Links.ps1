# 30_Extract_Links.ps1
# Extract additional CrowCanyon links from saved HTML, write discovered_links.txt

# Version History
# v1.1.0 Updated 8/19/25 - Rooted outputs; manual toggle honored

. "$PSScriptRoot\00_Config.ps1"
Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force

$HtmlFolder = $OutputRoot
$outFile = Join-Path $OutputRoot $DiscoveredListName

$hrefRegex = 'href\s*=\s*"(.*?)"'
$bag = [System.Collections.Generic.HashSet[string]]::new()

Get-ChildItem $HtmlFolder -Filter *.html | ForEach-Object {
  $html = Get-Content $_.FullName -Raw
  foreach ($m in [regex]::Matches($html, $hrefRegex, 'IgnoreCase')) {
    $h = $m.Groups[1].Value
    if ($h -match '^(mailto:|javascript:|#)') { continue }

    # Normalize + pass allow-list
    $norm = Normalize-Url $h
    try { $uri = [System.Uri]$norm } catch { continue }
    if (-not (Test-AllowList -Uri $uri -AllowedHosts $AllowedHosts -InfoPathPrefix $InfoPathPrefix)) { continue }

    # If it's a manual link and IncludeManual is false, skip
    if ($uri.Host -like '*crowcanyon.info' -and -not $IncludeManual) { continue }

    if ($uri.AbsolutePath -notmatch '\.(html?|aspx)$') { continue }
    [void]$bag.Add($uri.AbsoluteUri)
  }
}

$bag | Sort-Object | Set-Content -Encoding UTF8 $outFile
Write-Host "Wrote $($bag.Count) links -> $outFile"
