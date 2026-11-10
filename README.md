<div align="center">

# 🔍 ReconX v2.0

### Automated Bug Bounty Reconnaissance Framework

[![Bash](https://img.shields.io/badge/Made%20with-Bash-1F425F.svg)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-2.0-blue.svg)]()
[![Author](https://img.shields.io/badge/Author-DarkVictor--sudo-red.svg)](https://github.com/DarkVictor-sudo)

**One script. 14 modules. Full attack surface.**

ReconX automates the complete bug bounty reconnaissance pipeline — from subdomain enumeration to vulnerability detection — with an interactive module selector and smart auto-dependency resolution.

</div>

---

## ⚡ Features

- 🎯 **Interactive Module Selector** — run individual modules or the full pipeline
- 🔗 **Auto-Dependency Resolution** — modules automatically trigger their prerequisites
- 📁 **Organized Output** — structured results with session logging
- 🚀 **14 Recon Modules** — subdomain enum, XSS hunting, takeover checks & more
- 🎨 **Color-Coded Terminal Output** — clean, readable logs

---

## 📦 Modules

| # | Module | Tools |
|---|--------|-------|
| 1 | Subdomain Enumeration | `subfinder` |
| 2 | Live Host Probing | `httpx` |
| 3 | URL Collection | `gau`, `waybackurls` |
| 4 | JS Analysis + Secrets | `katana`, `curl` |
| 5 | Nuclei Scan (medium+) | `nuclei` |
| 6 | Full CVE Sweep | `nuclei` |
| 7 | XSS Hunting | `gf`, `kxss`, `dalfox` |
| 8 | Subdomain Takeover | `subzy` |
| 9 | CORS Misconfiguration | `curl` |
| 10 | Admin Panel Discovery | `curl` |
| 11 | Sensitive Files + Git Exposure | `curl` |
| 12 | GraphQL Introspection | `curl` |
| 13 | Open Redirect Candidates | `gf` |
| 14 | GF Patterns (exploit-ready URLs) | `gf` |

---

## 🛠️ Installation

### Prerequisites

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/hahwul/dalfox/v2/cmd/dalfox@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/tomnomnom/gf@latest
git clone https://github.com/1ndianl33t/Gf-Patterns ~/.gf
go install -v github.com/tomnomnom/hacks/kxss@latest
go install -v github.com/Luka967/subzy/v2@latest
sudo apt install -y curl jq
```

### Setup

```bash
git clone https://github.com/DarkVictor-sudo/reconX.git
cd reconX
chmod +x reconX.sh
```

---

## 🚀 Usage

```bash
./reconX.sh target.com
```

Select specific modules:

```
Select modules (e.g. 1,3,7 | a = all | 0 = exit): 1,2,7
```

Run everything:

```
Select modules (e.g. 1,3,7 | a = all | 0 = exit): a
```

---

## 📁 Output Structure

```
~/recon/<target>/<date>/
├── subdomains/       # all_subs.txt
├── probing/          # live.txt, live_detailed.txt
├── urls/             # all_urls.txt
├── js/               # js_files.txt, js_secrets.txt
├── exploits/         # nuclei, xss, takeover, cors, admin, graphql...
└── recon.log         # full session log
```

---

## ⚠️ Disclaimer

This tool is intended **only for authorized security testing** and educational purposes. Always obtain explicit permission before testing any target. Unauthorized scanning is illegal. The author is not responsible for any misuse of this tool.

---

## 👤 Author

**DarkVictor-sudo** — [GitHub](https://github.com/DarkVictor-sudo)

## 📜 License

MIT License — see [LICENSE](LICENSE)
