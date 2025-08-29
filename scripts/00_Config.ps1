# 00_Config.ps1
# Version History
# v2.1.0 2025-08-19 — Added optional cookie-based auth; v2 architecture (HTML_Source cache + offline builds)

# --- Runtime switches ---
$IncludeManual = $true
$StartId       = 1
$EndId         = 999

# --- Root paths (everything in the current folder) ---
$OutputRoot     = $PSScriptRoot
$SeedListName   = 'kb_links.txt'
$DiscoveredList = 'discovered_links.txt'

# One canonical cache of downloaded content (network touches happen here only)
$ContentFolder  = Join-Path $OutputRoot 'HTML_Source'

# Per-mode build folders (offline, derived from ContentFolder)
$RelFolder      = Join-Path $OutputRoot 'HTML_Relative'
$AbsFolder      = Join-Path $OutputRoot 'HTML_Absolute'

# --- Domain allow-list ---
$AllowedHosts   = @('www.crowcanyon.help','crowcanyon.help','www.crowcanyon.info','crowcanyon.info')
$InfoPathPrefix = '/nitro/'

# --- Link modes ---
$AbsoluteRoot   = ''  # e.g. https://<tenant>.sharepoint.com/sites/Site/Shared%20Documents/CrowCanyonKB

# --- Auth (optional) ---
$UseCookieAuth = $true
$CookieString  = 'hblid=sHlqqa02eiI2sYAO6y8LU0W0Dj0c0A6I; olfsk=olfsk7400139367511631; asgarosforum_unread_cleared=1000-01-01%2000%3A00%3A00; asgarosforum_unread_exclude=%7B%22367%22%3A1163%2C%22368%22%3A1172%7D; wp-settings-124=editor_plain_text_paste_warning%3D2; wp-settings-time-124=1755295451; _gid=GA1.2.1975479187.1755627084; _ga_F5YR9TWF0S=GS2.1.s1755729249$o25$g0$t1755729249$j60$l0$h0; _ga=GA1.2.309702976.1752603757; _gat_gtag_UA_125428320_1=1; wcsid=Uw8kdgXyTtR308Lj6y8LU0W0AS0jzr0k; _oklv=1755729249491%2CUw8kdgXyTtR308Lj6y8LU0W0AS0jzr0k; _okdetect=%7B%22token%22%3A%2217557292495340%22%2C%22proto%22%3A%22about%3A%22%2C%22host%22%3A%22%22%7D; _okbk=cd4%3Dtrue%2Cvi5%3D0%2Cvi4%3D1755729249823%2Cvi3%3Dactive%2Cvi2%3Dfalse%2Cvi1%3Dfalse%2Ccd8%3Dchat%2Ccd6%3D0%2Ccd5%3Daway%2Ccd3%3Dfalse%2Ccd2%3D0%2Ccd1%3D0%2C; _ok=8107-302-10-8606; wp-settings-124=editor_plain_text_paste_warning%3D2; wp-settings-time-124=1753286934; asgarosforum_unread_cleared=1000-01-01%2000%3A00%3A00; asgarosforum_unread_exclude=%7B%22368%22%3A1175%7D; _okdetect=%7B%22token%22%3A%2217555511123560%22%2C%22proto%22%3A%22about%3A%22%2C%22host%22%3A%22%22%7D; _ok=8107-302-10-8606; _gid=GA1.2.515713126.1755713994; wcsid=1jBzVG5S5GXDoqwx6y8LU0W000rjSdbz; _okbk=cd4%3Dtrue%2Cvi5%3D0%2Cvi4%3D1755713994863%2Cvi3%3Dactive%2Cvi2%3Dfalse%2Cvi1%3Dfalse%2Ccd8%3Dchat%2Ccd6%3D0%2Ccd5%3Daway%2Ccd3%3Dfalse%2Ccd2%3D0%2Ccd1%3D0%2C; _ga_F5YR9TWF0S=GS2.1.s1755713994$o11$g1$t1755715000$j60$l0$h0; _ga=GA1.2.1021115364.1752770699; _gat_gtag_UA_125428320_1=1; _oklv=1755715014576%2C1jBzVG5S5GXDoqwx6y8LU0W000rjSdbz'   # Paste 'name=value; name2=value2' here if login is required
$CookieDomains = @('www.crowcanyon.help','crowcanyon.help','www.crowcanyon.info','crowcanyon.info')

# --- Crawl pacing / rate limiting (v2.1.4) ---
$MinGapMs          = 600     # min ms between requests (with small jitter)
$SoftThrottleAfter = 25      # pause after this many requests
$CooldownSec       = 8       # short cooldown between small batches
$RecoveryPauseSec  = 60      # larger pause when the server looks tarpitted

# --- Fetch tuning ---
$MaxRetries = 5; $MinBackoffMs = 300; $MaxBackoffMs = 3000

# --- Filenames inside each folder ---
$ManifestName = 'Manifest.csv'   # Url,LocalFile,Status,Title,ETag,LastModified,Sha256,LastFetched
$FailuresName = 'Failures.log'
$IndexName    = 'index.html'
$BundleName   = 'bundle.json'

# NOTE: Place cookie string in single quotes to avoid PowerShell variable expansion.
