# 50_Rewrite_Links.ps1
# Rewrite internal links to local files per LinkMode

# Version History
# v1.2.0 Updated 8/19/25 - Read/write within mode folder

. "$PSScriptRoot\00_Config.ps1"
Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force

$manifest = Join-Path $HtmlFolder $ManifestName

$map = @{}
Import-Csv $manifest | ForEach-Object {
  if ($_.Status -eq 'Downloaded' -and $_.LocalFile) { $map[$_.Url] = $_.LocalFile }
}

Get-ChildItem $HtmlFolder -Filter *.html | ForEach-Object {
  if ($_.Name -in $IndexName) { return } # don't rewrite the index itself
  $path = $_.FullName
  $html = Get-Content $path -Raw

  $newHtml = [regex]::Replace($html, 'href\s*=\s*"([^"]+)"', {
    param($m)
    $h = $m.Groups[1].Value
    if ($h -match '^(mailto:|javascript:|#)') { return $m.Value }

    $norm = Normalize-Url $h
    try { $u = [System.Uri]$norm } catch { return $m.Value }

    if (-not $map.ContainsKey($u.AbsoluteUri)) { return $m.Value }

    $file = $map[$u.AbsoluteUri]
    $href = if ($LinkMode -eq 'Absolute' -and $AbsoluteRoot) {
      ($AbsoluteRoot.TrimEnd('/') + '/' + [Uri]::EscapeUriString($HtmlModeFolder + '/' + $file))
    } else {
      [Uri]::EscapeUriString($file)   # relative within mode folder
    }
    'href="' + $href + '"'
  }, 'IgnoreCase')

  if ($newHtml -ne $html) {
    $newHtml | Set-Content -Encoding UTF8 $path
    Write-Host "Rewrote links -> $path"
  }
}

# Post-rewrite integrity check (added by automation)
try { Test-RewriteIntegrity } catch { Write-Warning $_ }
