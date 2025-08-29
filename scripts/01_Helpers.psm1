# 01_Helpers.psm1
# Version History
# v2.1.0 2025-08-19 — Adds cookie session helper; Invoke-Web-Smart now supports -Headers and -WebSession
# v2.1.2 2025-08-19 — Added on-screen auth banner (cookie vs public)

function Show-AuthBanner {
    if ($UseCookieAuth -and $CookieString) {
        Write-Host "[Auth] Using cookie auth for domains: $($CookieDomains -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "[Auth] No cookie auth configured (public mode)" -ForegroundColor Yellow
    }
}

function Normalize-Url {
  param([string]$Url)
  if (-not $Url) { return $null }
  try {
    $u = [System.Uri]$Url
    $qs = [System.Web.HttpUtility]::ParseQueryString($u.Query)
    foreach($k in 'utm_source','utm_medium','utm_campaign','utm_term','utm_content'){ $qs.Remove($k) }
    $b = [System.UriBuilder]$u; $b.Query = ($qs.Count -gt 0) ? ($qs.AllKeys | sort | % { "$_=$($qs[$_])" } -join '&') : $null
    return $b.Uri.AbsoluteUri.TrimEnd('/')
  } catch { return $Url }
}

function Test-AllowList {
  param([System.Uri]$Uri,[string[]]$AllowedHosts,[string]$InfoPathPrefix='/nitro/')
  if (-not $Uri) { return $false }
  if ($AllowedHosts -notcontains $Uri.Host.ToLowerInvariant()) { return $false }
  if ($Uri.Host -like '*crowcanyon.info' -and -not $Uri.AbsolutePath.ToLowerInvariant().StartsWith($InfoPathPrefix)) { return $false }
  return $true
}

function Get-IdSlugFromUrl {
  param([System.Uri]$Uri)
  $id=$null; if ($Uri.AbsolutePath -match '/article/(\d+)') { $id=$Matches[1] }
  $slug = ($Uri.Segments[-1]).TrimEnd('/'); if (-not $slug -or $slug -match '^\d+$') { $slug='page' }
  $slug = ($slug -replace '\.html?$','')
  @{ Id=$id; Slug=$slug }
}

function Sanitize-Name([string]$Name,[int]$Max=120){
  $n=$Name.ToLowerInvariant() -replace '[^a-z0-9\-]+','-' -replace '\-+','-'
  $n=$n.Trim('-'); if($n.Length -gt $Max){ $n=$n.Substring(0,$Max).Trim('-') } ; return $n
}

function Map-UrlTo-LocalFile([System.Uri]$Uri,[string]$Folder){
  $m=Get-IdSlugFromUrl $Uri; $id=($m.Id ? "article-$($m.Id)-" : ''); $slug=Sanitize-Name $m.Slug
  Join-Path $Folder "$id$slug.html"
}

function New-CCWebSession {
  param(
    [Parameter(Mandatory)][string]$CookieString,
    [string[]]$Domains
  )
  $sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $pairs = $CookieString -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  foreach ($d in $Domains) {
    foreach ($p in $pairs) {
      $kv = $p -split '=', 2
      if ($kv.Count -eq 2) {
        $c = New-Object System.Net.Cookie
        $c.Name   = $kv[0].Trim()
        $c.Value  = $kv[1].Trim()
        $c.Domain = $d
        $sess.Cookies.Add($c)
      }
    }
  }
  return $sess
}


function Get-Page-Metadata {
  param([Parameter(Mandatory)] $Resp)
  $title = ''
  $content = $null; try { $content = $Resp.Content } catch {}
  if ($null -ne $content) {
    if ($content -is [byte[]]) { $content = [System.Text.Encoding]::UTF8.GetString($content) }
    if ($content -match '<title>(.*?)</title>') {
      $title = ($Matches[1] -replace '[
]+',' ').Trim()
    }
  }
  $etag    = $null; try { $etag = $Resp.Headers.ETag } catch {}
  $lastMod = $null; try { $lastMod = $Resp.Headers.'Last-Modified' } catch {}
  @{ Title=$title; ETag=$etag; LastModified=$lastMod }
}
$etag=$Resp.Headers.ETag
  $lastMod=$Resp.Headers.'Last-Modified'
  @{ Title=$title; ETag=$etag; LastModified=$lastMod }

function Get-FileSha256([string]$Path){
  if(-not (Test-Path $Path)){ return $null }
  $h = Get-FileHash -Algorithm SHA256 -Path $Path
  return $h.Hash
}

function Write-ManifestRow([string]$ManifestPath,[hashtable]$Row){
  if(-not (Test-Path $ManifestPath)){
    "Url,LocalFile,Status,Title,ETag,LastModified,Sha256,LastFetched" | Set-Content -Encoding UTF8 $ManifestPath
  }
  "$($Row.Url),$($Row.LocalFile),$($Row.Status),""$($Row.Title)"",$($Row.ETag),$($Row.LastModified),$($Row.Sha256),$([DateTime]::UtcNow.ToString('s'))" |
    Add-Content -Encoding UTF8 $ManifestPath
}

function Ensure-Folder([string]$Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Path $Path | Out-Null } }

function Safe-Copy-Tree([string]$From,[string]$To){
  Ensure-Folder $To
  Get-ChildItem $From -Filter *.html | % { Copy-Item $_.FullName -Destination (Join-Path $To $_.Name) -Force }
  foreach($f in @('Manifest.csv','Failures.log')){ if(Test-Path (Join-Path $From $f)){ Copy-Item (Join-Path $From $f) -Destination (Join-Path $To $f) -Force } }
}

Export-ModuleMember -Function *-*
Export-ModuleMember -Function Show-AuthBanner

# v2.1.4 2025-08-20 — Respect-Rate pacing + Retry-After aware backoff
$script:_rateStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:_sinceCooldown = 0


function Respect-Rate {
    param(
        [string]$HostKey,
        [int]$MinDelayMs = 350,
        [int]$MaxBurst = 4
    )
    if (-not $script:RateState) { $script:RateState = @{} }
    $state = $script:RateState[$HostKey]
    if (-not $state) {
        $state = [ordered]@{ Tokens=$MaxBurst; Last=Get-Date }
        $script:RateState[$HostKey] = $state
    }

    $now = Get-Date
    $elapsed = ($now - $state.Last).TotalMilliseconds
    $refill = [math]::Floor($elapsed / $MinDelayMs)
    if ($refill -gt 0) {
        $state.Tokens = [math]::Min($MaxBurst, $state.Tokens + $refill)
        $state.Last = $now
    }
    if ($state.Tokens -le 0) {
        $sleep = Get-Random -Minimum $MinDelayMs -Maximum ($MinDelayMs + 250)
        Start-Sleep -Milliseconds $sleep
    } else {
        $state.Tokens--
    }
}

function Handle-Backoff {
    param(
        [int]$Attempt,
        [int]$MaxAttempts = 6,
        [System.Net.Http.HttpResponseMessage]$Response,
        [int]$DefaultBaseMs = 750
    )

    if ($env:NITROKB_FORCE_BACKOFF -eq "1" -and ($Attempt % 3 -eq 0)) {
        $forced = Get-Random -Minimum 1000 -Maximum 3000
        Write-Verbose "Forced backoff for testing: ${forced}ms"
        Start-Sleep -Milliseconds $forced
        return
    }

    if ($Attempt -ge $MaxAttempts) { throw "Max attempts ($MaxAttempts) reached." }

    if ($Response -and [int]$Response.StatusCode -eq 404) {
        throw "HTTP 404 (Not Found) — bailing fast (attempt $Attempt)."
    }

    $delayMs = $null
    $retryAfter = $Response?.Headers?.RetryAfter
    if ($retryAfter) {
        if ($retryAfter.Delta) {
            $delayMs = [int][math]::Ceiling($retryAfter.Delta.Value.TotalMilliseconds)
        } elseif ($retryAfter.Date) {
            $span = ($retryAfter.Date.Value - (Get-Date))
            $delayMs = [int][math]::Max(0, [math]::Ceiling($span.TotalMilliseconds))
        }
    }

    if (-not $delayMs) {
        $exp = [math]::Pow(2, [math]::Min($Attempt, 6))
        $base = $DefaultBaseMs * $exp
        $jitter = Get-Random -Minimum 0 -Maximum ([int]($base * 0.25))
        $delayMs = [int]$base + $jitter
    }

    Write-Verbose "Backoff: sleeping $delayMs ms (attempt $Attempt)."
    Start-Sleep -Milliseconds $delayMs
}

function Invoke-Web-Smart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [string]$Method = 'GET',
        [hashtable]$Headers,
        [int]$MaxAttempts = 6
    )

    $hostKey = ([Uri]$Uri).Host
    $attempt = 0
    do {
        $attempt++
        Respect-Rate -HostKey $hostKey
        try {
            $params = @{
                Uri = $Uri
                Method = $Method
                Headers = $Headers
                ResponseHeadersVariable = 'respHeaders'
                ErrorAction = 'Stop'
            }
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $resp = Invoke-WebRequest @params
            $sw.Stop()

            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                return [pscustomobject]@{
                    StatusCode   = $resp.StatusCode
                    Headers      = $respHeaders
                    RawContent   = $resp.Content
                    ContentBytes = [System.Text.Encoding]::UTF8.GetBytes($resp.Content)
                    DurationMs   = $sw.ElapsedMilliseconds
                }
            }

            Write-Verbose "HTTP $($resp.StatusCode) on attempt $attempt for $Uri"
            Handle-Backoff -Attempt $attempt -MaxAttempts $MaxAttempts -Response $resp.BaseResponse
        }
        catch {
            Write-Verbose "Network/Invoke error on attempt $attempt: $($_.Exception.Message)"
            Handle-Backoff -Attempt $attempt -MaxAttempts $MaxAttempts -Response $null
        }
    } while ($attempt -lt $MaxAttempts)

    throw "Invoke-Web-Smart failed after $MaxAttempts attempts: $Uri"
}

function Get-StableHash {
    param([string]$Html)
    $norm = $Html -replace '(?ms)<!--.*?-->', '' `
                  -replace '(?ms)\s+', ' ' `
                  -replace '(?i)nonce="[^"]+"', 'nonce=""'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm.Trim())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    ($sha.ComputeHash($bytes) | ForEach-Object ToString x2) -join ''
}

function Test-RewriteIntegrity {
    param([string]$Root = ".\CacheRoot")
    $bad = Get-ChildItem $Root -Recurse -Include *.html |
      ForEach-Object {
        $html = Get-Content $_.FullName -Raw
        if ($html -match 'https?://(www\.)?crowcanyon\.info/.*?') {
            [pscustomobject]@{ File = $_.FullName; Match = $Matches[0] }
        }
      }
    if ($bad) {
        $bad | Format-Table -AutoSize | Out-String | Write-Host
        throw "Found absolute Crow Canyon links post-rewrite."
    }
    Write-Host "Rewrite integrity: OK"
}
