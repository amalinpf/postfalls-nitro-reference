<#
.SYNOPSIS
  Builds a simple full-text index (JSON) from kb-html/*.html for client-side search.
#>
param(
  [string]$KbFolder = ".\kb-html",
  [string]$OutFile  = ".\kb-html\kb-index.json",
  [int]$MaxChars    = 40000,     # cap content per file
  [string]$BaseUrl  = "https://amalinpf.github.io/postfalls-nitro-reference/kb-html/"
)

function Strip-Html {
  param([string]$Html)
  $noScripts = [regex]::Replace($Html, "<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>", "", "Singleline,IgnoreCase")
  $noStyles  = [regex]::Replace($noScripts, "<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>", "", "Singleline,IgnoreCase")
  $text      = [regex]::Replace($noStyles, "<[^>]+>", " ")
  $text      = [regex]::Replace($text, "\s+", " ")
  return $text.Trim()
}

$items = @()
Get-ChildItem -Path $KbFolder -Filter *.html -File | ForEach-Object {
  $name = $_.Name
  $html = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
  $text = Strip-Html $html
  if ($text.Length -gt $MaxChars) { $text = $text.Substring(0, $MaxChars) }

  $idMatch = [regex]::Match($name, "(\d{1,6})")
  $id = if ($idMatch.Success) { $idMatch.Groups[1].Value } else { $name }

  $urlName = [System.Uri]::EscapeDataString($name)
  $url = $BaseUrl + $urlName

  $base = [regex]::Replace($name, "\.html?$", "", "IgnoreCase")
  $t = $base -replace "[-_]+"," "
  $t = [regex]::Replace($t, "\s*-\s*Crow\s*Canyon.*$", "", "IgnoreCase")
  $t = [regex]::Replace($t, "^\d+\s*(?:-\s*)?", "")
  $ti = ($t -split " ") | ForEach-Object { if ($_){ $_[0].ToString().ToUpper()+$_.Substring(1) } }
  $title = ($ti -join " ").Trim()

  $items += [pscustomobject]@{
    id    = $id
    name  = $name
    url   = $url
    title = $title
    text  = $text
  }
}

$items | ConvertTo-Json -Depth 3 | Out-File -LiteralPath $OutFile -Encoding UTF8
Write-Host "Wrote $($items.Count) records to $OutFile"
