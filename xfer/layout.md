# GPT-4o Context for NITRO Manual Project

## User & Context
- **Name:** Art Malin  
- **Org:** City of Post Falls IT Workspace (small city government setting)  
- **Email:** amalin@postfalls.gov  
- **Role:** IT staff, building SharePoint/NITRO Studio systems and documentation.  
- **Retirement:** planned 2026-09-30.  

## Preferences & Style
- Prefers **compact formatting** (no double-spacing).  
- Likes concise technical responses with light humor (IT sarcasm, Clippy-style jokes).  
- Prefers **12px font** for Function + Description columns (set in CSS, not inline).  
- Wants **external CSS** (not inline), with theme variants (e.g., 4Lighter/4Darker, 5Lighter/5Darker).  
- Uses **versioning for CSS** (numbered themes for A/B comparison).  
- Likes **expand/collapse (`<details>`) sections** with triangle indicators.  
- Wants **page structure identical to “Format Source”** (`index.html`).  
- Uses **Repo Root** and KB articles hosted on GitHub Pages as canonical sources.  
- Likes YAML hierarchies for categories/groups as a single source of truth.  
- All examples/emails should use the `@postfalls.gov` domain.  
- Prefers **Outlook-compatible HTML** when generating emails.  

## NITRO Manual Project
- **Repo Root:** https://amalinpf.github.io/postfalls-nitro-reference  
- **KB Article Root:** https://amalinpf.github.io/postfalls-nitro-reference/kb-html/  
- **Static links page:** https://amalinpf.github.io/postfalls-nitro-reference/test/nitro_static_links.html  
- **Format Source (WIP index):** https://amalinpf.github.io/postfalls-nitro-reference/index.html  
- **KB ZIP (all articles):** https://amalinpf.github.io/postfalls-nitro-reference/xfer/NITRO_KB.zip  
- **Supplemental docs ZIP:** https://amalinpf.github.io/postfalls-nitro-reference/xfer/SupplementalReferenceDocs.zip  
- **Primary CSS location:** https://amalinpf.github.io/postfalls-nitro-reference/css/nitro.css  
- **Working branch:** `manual/test/generation`  

### Categories & Groups
- **Functions** (top-level category, groups indented one level deeper):  
  - 🔤 String Functions  
  - 🔢 Math & Calculation  
  - 📅 Date & Time Functions  
  - 📊 Lookup & JSON  
  - 🔀 Conversion & Formatting  
  - 👥 People Field Handling  
  - ⚙️ Utility & Misc  
  - 🧮 Logical Functions  
- Other categories (single icon each):  
  - 🧠 JavaScript Examples  
  - 📎 Placeholders  
  - 📬 Email Syntax  
  - 🧩 Advanced Conditions  
  - 👥 People Field Handling  
  - 🛠 Workflows  
  - ⚡ Custom Actions  
  - 💡 Tips & Tricks  
  - 🗂 Known Issues & Fixes  
  - 🔐 Admin / Advanced  
  - ➕ Other Categories  

## Current Status
- String Functions already populated in HTML test pages.  
- YAML hierarchy built and aligned with Format Source.  
- HTML prototypes tested with external CSS (4*/5*).  
- Inline styles successfully externalized into CSS.  
- Next step: populate **all remaining function groups** with condensed rows, use YAML as source of truth, and test CSS theme variations.