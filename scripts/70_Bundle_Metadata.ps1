# 70_Bundle_Metadata.ps1
# Save runtime + counts to bundle.json for future ChatGPT processing

# Version History
# v1.2.0 Updated 8/19/25 - Write bundle.json inside mode folder

. "$PSScriptRoot\00_Config.ps1"

$manifest = Join-Path $HtmlFolder $ManifestName
$bundle   = Join-Path $HtmlFolder $BundleName

$rows = if (Test-Path $manifest) { Import-Csv $manifest } else { @() }
$stats = [pscustomobject]@{
  generatedAt   = (Get-Date).ToString('s')
  includeManual = $IncludeManual
  linkMode      = $LinkMode
  absoluteRoot  = $AbsoluteRoot
  htmlFolder    = $HtmlModeFolder
  counts        = @{
    downloaded = ($rows | Where-Object {$_.Status -eq 'Downloaded'}).Count
    failed     = ($rows | Where-Object {$_.Status -eq 'Failed'}).Count
    total      = $rows.Count
  }
  allowList     = $AllowedHosts
  outputRoot    = (Resolve-Path $OutputRoot).Path
}
$stats | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $bundle
Write-Host "Wrote bundle -> $bundle"
