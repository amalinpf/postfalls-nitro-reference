# NITRO-KB Scraping & Bundling Scripts

This folder contains the PowerShell tooling used to scrape, cache, and bundle Crow Canyon NITRO Studio Knowledge Base (KB) articles for offline/local use.

---

## 🛠 Script Workflow (10 → 70)

The scripts are modular and can be run individually, or orchestrated with `RunAll_v2.ps1`.

| Step | Script                        | Purpose |
|------|-------------------------------|---------|
| 00   | `00_Config.ps1`               | Runtime options (auth method, cookie string, output folders, etc.) |
| 01   | `01_Helpers.psm1`             | Custom helper module (web requests, session handling, rate limiting, retry/backoff) |
| 10   | `10_FindKB.ps1`               | Identify KB URLs (new/changed vs cached) |
| 20   | `20_Download_FirstLevel.ps1`  | Download first-level KB articles |
| 30   | `30_Extract_Links.ps1`        | Extract links to additional/related KBs |
| 40   | `40_Download_Linked.ps1`      | Download linked KBs |
| 50   | `50_Rewrite_Links.ps1`        | Rewrite local links for offline usage |
| 60   | `60_Build_Index.ps1`          | Build an index of the cached KBs |
| 70   | `70_Bundle_Metadata.ps1`      | Bundle metadata for tracking and offline reference |

---

## 🚀 Orchestration

- **Run everything** (10 → 70) in sequence:
  ```powershell
  .\RunAll_v2.ps1
