# Crow Canyon KB Capture – v2

## Overview
This toolchain captures Crow Canyon KB articles into a **local, password-free bundle** that can be browsed offline or uploaded into a SharePoint library.
It separates **network fetches** (incremental downloads) from **offline builds** (Relative/Absolute link modes).

> **Auth note:** If your Crow Canyon KB requires login, this tool supports **cookie-based access**. You’ll paste a browser-copied Cookie string into `00_Config.ps1` and the scripts will send it on each request.

---

## Folder Structure
- `00_Config.ps1` – central settings (IDs, folders, constants, **optional cookie**).
- `01_Helpers.psm1` – shared functions (URL sanitize, retries, manifest, **cookie session**).
- `10_FindKB.ps1` – collect valid KB article URLs (respects cookie session).
- `20_Download_FirstLevel.ps1` – incremental download of first-level KBs → `HTML_Source/` (respects cookie session).
- `30_Extract_Links.ps1` – parse downloaded pages for Crow Canyon links.
- `40_Download_Linked.ps1` – incremental download of discovered linked KBs → `HTML_Source/` (respects cookie session).
- `50_Build_Mode.ps1` – offline build into `HTML_Relative/` or `HTML_Absolute/` (link rewrite, `index.html`, `bundle.json`).
- `Switch-Mode.ps1` – build both modes back-to-back from cache.
- `RunAll_v2.ps1` – runs only the network/incremental steps (10–40).

---

## Usage

### 0. (If required) Capture login cookie from your browser
If your Crow Canyon KB requires authentication, copy your cookie into `00_Config.ps1`:

**Chrome / Edge**  
1. Log into the KB in your browser.  
2. Press **F12** → **Application** tab → **Storage ▸ Cookies** → select the KB domain (e.g., `www.crowcanyon.help`).  
3. Copy the **Cookie header** value:
   - Option A: **Network** tab → select any KB page request → **Headers** → **Request Headers ▸ Cookie** → copy the entire line.
   - Option B: In **Application ▸ Cookies**, manually build `name=value; name2=value2; ...` from relevant cookies.  
4. In `00_Config.ps1`, set:
   ```powershell
   # Paste your cookie string between single quotes (example below)
   $UseCookieAuth = $true
   $CookieString  = 'SESSIONID=abc123; .ASPXAUTH=xyz456; OtherCookie=value'
   # (Optional) add domains if your auth spans multiple hosts
   $CookieDomains = @('www.crowcanyon.help','crowcanyon.help','www.crowcanyon.info','crowcanyon.info')
   ```
**Notes**
- Treat the cookie like a password. Rotate it if it leaks or expires.  
- If you begin seeing 401/403 responses, re-copy a fresh cookie after logging in again.  
- This tool **does not** capture cookies from your browser automatically (browsers isolate cookie stores).

### 1. Refresh KB Cache (network, incremental)
```powershell
.\RunAll_v2.ps1
```
- Fetches new/changed KBs into `HTML_Source/`.
- Uses ETag/Last-Modified headers + SHA256 to avoid re-downloading unchanged files.
- Sends your cookie (if configured) with each request.

### 2. Build Outputs Offline
```powershell
.\Switch-Mode.ps1 -AbsoluteRoot 'https://<tenant>.sharepoint.com/sites/Site/Shared%20Documents/CrowCanyonKB'
```
- Generates `HTML_Relative/` (portable)  
- Generates `HTML_Absolute/` (SharePoint web links)

### 3. Legacy Compatibility
```powershell
.\NITRO-KB_FindKB.ps1
.\NITRO-KB_FirstLevelPages.ps1
.\NITRO-KB_GetLinkedPages.ps1
```
These run the v2 equivalents under the hood.

---

## Configuration Keys (auth-related)
In `00_Config.ps1` add these (if not already present):
```powershell
# --- Auth (optional) ---
$UseCookieAuth = $false
$CookieString  = ''   # Paste 'name=value; name2=value2' here if login is required
$CookieDomains = @('www.crowcanyon.help','crowcanyon.help','www.crowcanyon.info','crowcanyon.info')
```

---

## Notes
- **Cookies:** Only sent if `$UseCookieAuth` is `$true` and `$CookieString` is non-empty.
- **No passwords stored:** This tool only uses the cookie string you paste in.
- **Outputs:**
  - `HTML_Source/` → canonical cache of all fetched KBs.
  - `HTML_Relative/` → offline portable build.
  - `HTML_Absolute/` → SharePoint-ready build.

---
*Version v2.1.0 – 2025-08-19: Added cookie-based auth instructions*

## File Map (names, locations, purpose)

| File | Purpose |
|---|---|
| `00_Config.ps1` | Global settings (paths, auth, domains, switches) |
| `01_Helpers.psm1` | Shared helper functions (URL, retries, manifest, auth banner) |
| `10_FindKB.ps1` | Identify KB article URLs (new/changed) for download queue |
| `20_Download_FirstLevel.ps1` | Download first-level KB pages incrementally into cache |
| `30_Extract_Links.ps1` | Parse cached pages to discover KB links |
| `40_Download_Linked.ps1` | Download discovered linked KBs incrementally into cache |
| `50_Rewrite_Links.ps1` | Rewrite links for offline/portable viewing |
| `60_Build_Index.ps1` | Generate index.html (TOC) |
| `70_Bundle_Metadata.ps1` | Emit bundle.json / manifest rollup |
| `NITRO-KB_FindKB.ps1` | Legacy shim: calls 10_FindKB.ps1 |
| `NITRO-KB_FirstLevelPages.ps1` | Legacy shim: calls 20_Download_FirstLevel.ps1 |
| `NITRO-KB_GetLinkedPages.ps1` | Legacy shim: runs 30 + 40 |
| `README.md` | — |
| `RunAll.ps1` | Legacy: run 10–70 in one shot |
| `RunAll_v2.ps1` | Run 10–40 (network) then 50–70 (offline) |
| `Switch-Mode.ps1` | Rebuild outputs without network |

> **Note:** When requesting changes, please **zip and return the entire folder** so updates are applied to the latest files without losing prior edits.


## Test Harness
Use `./RunAll_TestHarness.ps1 -ForceBackoff -MaxKB 50` to validate retry/backoff and keep load modest.
