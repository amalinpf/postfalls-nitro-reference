# 20_KB_Download.ps1
# Download Crow Canyon KB articles listed in ValidUrls.csv with throttling/backoff.
# Writes status back to ValidUrls.csv after each row (resume-safe).

# Version History
# v1.1.1 Updated 8/20/25 - Filename: "<ArticleId> - <Title>.html" and trim " - Crow Canyon Software Support"
# v1.1.0 Updated 8/20/25 - Use "<ArticleId> - <Title>.html" and $PSScriptRoot paths
# v1.0.0 - Initial

param(
    [string]$CsvPath          = (Join-Path $PSScriptRoot "ValidUrls.csv"),
    [string]$OutDir           = (Join-Path $PSScriptRoot "KBDownloads"),
    [int]$BaseDelaySeconds    = 5,
    [int]$JitterSeconds       = 5,
    [int]$MaxRetries          = 5
)

# Paths / setup
if (-not (Test-Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory | Out-Null }
if (-not (Test-Path $CsvPath)) { Write-Error "CSV not found: $CsvPath"; exit 1 }
$rows = Import-Csv -Path $CsvPath

# Browsery headers
$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"
$Headers = @{
  "Accept"          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
  "Accept-Language" = "en-US,en;q=0.9"
}

function Save-CsvRowState {
  param($allRows, $path)
  $tmp = [System.IO.Path]::GetTempFileName()
  try {
    $allRows | Export-Csv -Path $tmp -NoTypeInformation -Encoding UTF8
    Move-Item -Force $tmp $path
  } catch {
    Write-Warning "Failed to write CSV: $($_.Exception.Message)"
    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
  }
}

function Invoke-PoliteRequest {
  param([string]$Url, [int]$Try, [int]$BaseDelay, [int]$Jitter)
  $sleep = $BaseDelay + (Get-Random -Minimum 0 -Maximum $Jitter)
  if ($Try -gt 1) { $sleep = [Math]::Min(60, $sleep * [Math]::Pow(1.7, $Try-1)) }
  Start-Sleep -Seconds $sleep
  try {
    return Invoke-WebRequest -Uri $Url -UserAgent $UserAgent -Headers $Headers -MaximumRedirection 10 -TimeoutSec 30 -UseBasicParsing
  } catch { throw }
}

# Main loop
for ($i = 0; $i -lt $rows.Count; $i++) {
  $row = $rows[$i]
  if (-not $row.Status) { $row.Status = "Pending" }
  if ($row.Status -eq "Done") { Write-Host "Skipping (Done): $($row.Url)"; continue }
  if (-not $row.Url) { $row.Status = "Skipped"; $row.Notes = "Missing Url"; continue }

  # ---- Build filename: "<ArticleId> - <Title>.html" (trim vendor suffix)
  $aid   = $row.ArticleId
  if (-not $aid -or "$aid" -eq "") { $aid = "NA" }

  $title = ($row.PSObject.Properties.Name -contains "Title") ? $row.Title : $null
  if (-not $title -or $title -eq "") { $title = "Untitled" }

  # Trim common suffix variants (dash/en dash/em dash/pipe), case-insensitive
  $title = $title -replace '(?i)\s*[\-\|\–\—]\s*Crow Canyon Software Support$', ''

  # Sanitize for filesystem
  $safeTitle = ($title -replace '[\\/:*?"<>|]', '_').Trim()

  $fileName  = "$aid - $safeTitle.html"
  $row.FileName = $fileName
  $outPath   = Join-Path $OutDir $fileName
  # ----

  $ok = $false; $errShort = ""; $httpCode = ""
  for ($t = 1; $t -le $MaxRetries; $t++) {
    try {
      $resp = Invoke-PoliteRequest -Url $row.Url -Try $t -BaseDelay $BaseDelaySeconds -Jitter $JitterSeconds
      $httpCode = [int]$resp.StatusCode
      if ($httpCode -eq 200) {
        [System.IO.File]::WriteAllText($outPath, $resp.Content, [System.Text.Encoding]::UTF8)
        $ok = $true; break
      } elseif ($httpCode -in (429, 444)) {
        Write-Warning "Throttled (HTTP $httpCode) on try $t for $($row.Url)"
      } elseif ($httpCode -eq 404) {
        Write-Warning "404 for $($row.Url)"; break
      } else {
        Write-Warning "HTTP $httpCode for $($row.Url)"
      }
    } catch {
      $errShort = $_.Exception.Message
      Write-Warning "Error try $t for $($row.Url): $errShort"
    }
  }

  $row.LastTried = (Get-Date).ToString("s")
  if ($ok) {
    $row.Status = "Done";  $row.HttpStatus = $httpCode; $row.Error = ""; $row.Notes = ""
  } else {
    $row.Status = "Error"; $row.HttpStatus = $httpCode
    if ($errShort) { $row.Error = $errShort.Substring(0, [Math]::Min(180, $errShort.Length)) }
    if (-not $row.Notes) { $row.Notes = "Check throttling / URL validity" }
  }

  Save-CsvRowState -allRows $rows -path $CsvPath
  Write-Host "Processed [$($i+1)/$($rows.Count)]: $($row.Url) => $($row.Status) $httpCode"
}

Write-Host "Done."
