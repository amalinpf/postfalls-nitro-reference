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