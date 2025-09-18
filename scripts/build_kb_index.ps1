# build_kb_index.ps1
# Builds a lean JSON index from HTML files for full-text search. Strips common Crow Canyon boilerplate and limits main text content length.

# Version History
# v1.1.0 Updated 9/18/25 - Added regex cleanup for Crow Canyon headers/footers and updated naming conventions.

param(
  [string]$KbFolder = "..\kb-html",
  [string]$OutFile = "$KbFolder\kb-index-lean.json",
  [int]$CharsPerDoc = 5000,
  [ValidateSet("TitleOnly", "TitleAndMain")]
  [string]$IndexMode = "TitleAndMain"
)

Write-Host "Building index from $KbFolder..."
$docs = Get-ChildItem $KbFolder -Filter "*.html" -Recurse | Sort-Object Name

$results = @()
foreach ($f in $docs) {
  $html = Get-Content $f.FullName -Raw
  $html2 = $html -replace "(?s)<script.*?</script>", "" -replace "(?s)<style.*?</style>", ""
  $id = $f.Name
  $title = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $url = "https://amalinpf.github.io/postfalls-nitro-reference/kb-html/$($f.Name)"

  $text = ""
  if ($IndexMode -eq "TitleAndMain") {
    # Prefer extracting only the .entry-content block
    $main = ""
    if ($html2 -match '(?is)<div[^>]*class="[^"]*entry-content[^"]*"[^>]*itemprop="articleBody"[^>]*>(.*?)</div>') {
      $main = $Matches[1]
    }
    elseif ($html2 -match "(?is)<body[^>]*>(.*?)</body>") {
      $main = $Matches[1]
    }
    else {
      $main = $html2
    }

    # Strip tags, decode entities, clean whitespace
    $text = ($main -replace "(?s)<[^>]+>", " ") -replace "\s+", " "
    $text = [System.Net.WebUtility]::HtmlDecode($text).Trim()

    # Remove common Crow Canyon boilerplate (header/footer)
    $text = $text -replace "(?i)^.*?Support Homepage Community Forum Submit a Support Ticket CrowCanyon.com Website Version Release Notes Home /", ""
    $text = $text -replace "(?i)About supportTeam View all posts by supportTeam → Leave a Reply Cancel reply You must be logged in to post a comment\..*$", ""

    # Cap content
    $origLen = $text.Length
    if ($text.Length -gt $CharsPerDoc) {
      $text = $text.Substring(0, $CharsPerDoc)
      Write-Host "CLIPPED: $($f.Name) ($origLen characters)"
    }
  }

  $obj = [PSCustomObject]@{
    id    = $id
    title = $title
    url   = $url
    text  = $text
  }
  $results += $obj
}

# Save JSON
$json = $results | ConvertTo-Json -Depth 5
$destFolder = Split-Path -Parent $OutFile
if (-not (Test-Path $destFolder)) {
  New-Item -ItemType Directory -Path $destFolder | Out-Null
}
Set-Content -Path $OutFile -Value $json -Encoding UTF8
Write-Host "DONE: $($results.Count) docs written to $OutFile"