# 21_KB_RetryFailures.ps1
# Retry only rows with Status=Error or Pending in ValidUrls.csv (same logic as 20_).

# Version History
# v1.0.0 Updated 8/20/25 - Initial

param(
  [string]$CsvPath = (Join-Path $PSScriptRoot "ValidUrls.csv")
)

if (-not (Test-Path $CsvPath)) { Write-Error "CSV not found: $CsvPath"; exit 1 }

$rows  = Import-Csv -Path $CsvPath
$retry = $rows | Where-Object { $_.Status -in @("Error","Pending") }
if ($retry.Count -eq 0) { Write-Host "Nothing to retry."; exit 0 }

$tmpCsv = [System.IO.Path]::GetTempFileName()
try {
  $retry | Export-Csv -Path $tmpCsv -NoTypeInformation -Encoding UTF8

  $script20 = Join-Path $PSScriptRoot "20_KB_Download.ps1"
  if (-not (Test-Path $script20)) { Write-Error "Missing 20_KB_Download.ps1 next to this script."; exit 1 }

  & $script20 -CsvPath $tmpCsv

  $updated = Import-Csv -Path $tmpCsv
  $map = @{}
  foreach ($u in $updated) { $map[$u.Url] = $u }

  foreach ($row in $rows) {
    if ($map.ContainsKey($row.Url)) {
      $match = $map[$row.Url]
      $row.Status     = $match.Status
      $row.LastTried  = $match.LastTried
      $row.HttpStatus = $match.HttpStatus
      $row.Error      = $match.Error
      $row.Notes      = $match.Notes
      if (($null -eq $row.FileName) -or ($row.FileName -eq "")) { $row.FileName = $match.FileName }
    }
  }

  $tmpMain = [System.IO.Path]::GetTempFileName()
  $rows | Export-Csv -Path $tmpMain -NoTypeInformation -Encoding UTF8
  Move-Item -Force $tmpMain $CsvPath
}
finally {
  if (Test-Path $tmpCsv) { Remove-Item $tmpCsv -Force -ErrorAction SilentlyContinue }
}

Write-Host "Retry pass complete."
