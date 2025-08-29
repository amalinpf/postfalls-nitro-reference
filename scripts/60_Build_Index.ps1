# 60_Build_Index.ps1
# Build a SharePoint-friendly index.html with filter + KB/Manual toggles

# Version History
# v1.2.0 Updated 8/19/25 - Generate index inside mode folder and link appropriately

. "$PSScriptRoot\00_Config.ps1"
Import-Module "$PSScriptRoot\01_Helpers.psm1" -Force

$manifest = Join-Path $HtmlFolder $ManifestName
$index    = Join-Path $HtmlFolder $IndexName

$rows = Import-Csv $manifest | Where-Object { $_.Status -eq 'Downloaded' -and $_.LocalFile }

# Simple classify: KB vs Manual
foreach ($r in $rows) {
  $host = ([System.Uri]$r.Url).Host
  $r.Add('Category', ($(if ($host -like '*crowcanyon.info') {'Manual'} else {'KB'})))
}

# Build minimal, dependency-free HTML (search + filter)
$items = $rows | ForEach-Object {
  $title = if ($_.Title) { $_.Title } else { $_.Url }
  $href  = if ($LinkMode -eq 'Absolute' -and $AbsoluteRoot) {
    ($AbsoluteRoot.TrimEnd('/') + '/' + [Uri]::EscapeUriString($HtmlModeFolder + '/' + $_.LocalFile))
  } else {
    [Uri]::EscapeUriString($_.LocalFile)  # relative within mode folder
  }
@"
<li data-category="$($_.Category)">
  <a href="$href" target="_blank" rel="noopener">$([System.Web.HttpUtility]::HtmlEncode($title))</a>
  <div style="font-size:12px;color:#666;">$([System.Web.HttpUtility]::HtmlEncode($_.Url))</div>
</li>
"@
} | Out-String

$doc = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Crow Canyon KB Bundle ($LinkMode)</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Segoe UI,Tahoma,Arial,sans-serif;margin:24px}
h1{margin:0 0 12px 0}
.controls{display:flex;gap:12px;align-items:center;margin:12px 0 18px 0}
input[type=text]{padding:8px;border:1px solid #ccc;border-radius:6px;min-width:260px}
select{padding:8px;border:1px solid #ccc;border-radius:6px}
ul{list-style:none;padding:0;margin:0}
li{background:#fff;border:1px solid #e6e6e6;border-radius:10px;padding:12px 14px;margin:8px 0;box-shadow:0 1px 3px rgba(0,0,0,.05)}
a{color:#0078d4;text-decoration:none}
a:hover{text-decoration:underline}
.footer{margin-top:18px;font-size:12px;color:#888;text-align:right}
.mode{font-size:12px;color:#555;margin-bottom:6px}
</style>
</head>
<body>
<h1>Crow Canyon KB Bundle</h1>
<div class="mode">Mode: <strong>$LinkMode</strong> — Folder: <code>$HtmlModeFolder</code></div>
<div class="controls">
  <input id="q" type="text" placeholder="Filter by title or URL..." />
  <select id="cat">
    <option value="">All</option>
    <option value="KB">KB</option>
    <option value="Manual">Manual</option>
  </select>
</div>
<ul id="list">
$items
</ul>
<div class="footer"><em>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')</em></div>
<script>
const q = document.getElementById('q');
const cat = document.getElementById('cat');
const list = document.getElementById('list').children;
function apply(){ 
  const term = q.value.toLowerCase();
  const c = cat.value;
  for (const li of list){
    const text = li.innerText.toLowerCase();
    const okTerm = !term || text.includes(term);
    const okCat = !c || li.dataset.category === c;
    li.style.display = (okTerm && okCat) ? '' : 'none';
  }
}
q.addEventListener('input', apply);
cat.addEventListener('change', apply);
</script>
</body></html>
"@

$doc | Set-Content -Encoding UTF8 $index
Write-Host "Index built -> $index"
