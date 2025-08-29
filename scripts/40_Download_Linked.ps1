# v2.1.4 2025-08-20 — Added polite pacing via Respect-Rate
# 40_Download_Linked.ps1
# Version History
# v2.1.0 2025-08-19 — Cookie session support on incremental downloads

. "$PSScriptRoot\00_Config.ps1"
Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force

Ensure-Folder $ContentFolder
$disc     = Join-Path $OutputRoot $DiscoveredList
$manifest = Join-Path $ContentFolder $ManifestName
$failures = Join-Path $ContentFolder $FailuresName
if (-not (Test-Path $disc)) { throw "Missing $disc. Run 30_Extract_Links.ps1 first." }
if (-not (Test-Path $manifest)) { "Url,LocalFile,Status,Title,ETag,LastModified,Sha256,LastFetched" | Set-Content -Encoding UTF8 $manifest }

# Optional cookie session
$Session = $null
if ($UseCookieAuth -and $CookieString) {
  $Session = New-CCWebSession -CookieString $CookieString -Domains $CookieDomains
}

$prev=@{}; Import-Csv $manifest | % { $prev[$_.Url]=$_.PsObject.Properties.Value }

Get-Content $disc | ? { $_ } | % {
  $norm = Normalize-Url $_; try { $u=[uri]$norm } catch { return }
  $local = Map-UrlTo-LocalFile $u $ContentFolder
  $old = $prev[$norm]

  $headers=@{}
  if($old -and $old.ETag)        { $headers['If-None-Match']     = $old.ETag }
  if($old -and $old.LastModified){ $headers['If-Modified-Since']  = $old.LastModified }

  try{
Respect-Rate
    $resp = Invoke-Web-Smart -Url $norm -Headers $headers -WebSession $Session `
            -MaxRetries $MaxRetries -MinBackoffMs $MinBackoffMs -MaxBackoffMs $MaxBackoffMs
    $meta = Get-Page-Metadata $resp
    $resp.Content | Set-Content -Encoding UTF8 $local
    $sha = Get-FileSha256 $local
    Write-ManifestRow $manifest @{ Url=$norm; LocalFile=(Split-Path $local -Leaf); Status='Downloaded'; Title=$meta.Title; ETag=$meta.ETag; LastModified=$meta.LastModified; Sha256=$sha }
    Write-Host "Updated -> $local"
  } catch {
    $sc=$null; try{ $sc = $_.Exception.Response.StatusCode.Value__ }catch{}
    if($sc -eq 304){
      Write-ManifestRow $manifest @{ Url=$norm; LocalFile=(Split-Path $local -Leaf); Status='Unchanged'; Title=$old.Title; ETag=$old.ETag; LastModified=$old.LastModified; Sha256=$old.Sha256 }
      Write-Host "Unchanged -> $local"
    } else {
      "$norm`t$($_.Exception.Message)" | Add-Content -Encoding UTF8 $failures
      Write-ManifestRow $manifest @{ Url=$norm; LocalFile=''; Status='Failed'; Title=''; ETag=''; LastModified=''; Sha256='' }
      Write-Warning "Failed $norm"
    }
  }
}
