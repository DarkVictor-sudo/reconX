#!/bin/bash
# ================================================================
#   ReconX v2.0 — Automated Recon with Interactive Module Selector
#   Author : DarkVictor-sudo
#   Usage  : ./reconX.sh target.com
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Usage: ./reconX.sh target.com${NC}"
    exit 1
fi

TODAY=$(date +%F)
OUT="$HOME/recon/$DOMAIN/$TODAY"
mkdir -p "$OUT"/{subdomains,probing,urls,js,exploits}

log()  { echo -e "${CYAN}[*]${NC} $1" | tee -a "$OUT/recon.log"; }
ok()   { echo -e "${GREEN}[+]${NC} $1" | tee -a "$OUT/recon.log"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$OUT/recon.log"; }

# ---------- AUTO-DEPENDENCIES (module khud apni inputs bana lega) ----------
needs_subs() { [ -s "$OUT/subdomains/all_subs.txt" ] || { warn "Subdomains missing - enum pehle"; mod_subdomains; } }
needs_live() { needs_subs; [ -s "$OUT/probing/live.txt" ] || { warn "Live hosts missing - probing pehle"; mod_probing; } }
needs_urls() { needs_live; [ -s "$OUT/urls/all_urls.txt" ] || { warn "URLs missing - collecting pehle"; mod_urls; } }

# ================================================================
#   MODULES
# ================================================================

mod_subdomains() {
    log "[1] Subdomain Enumeration"
    subfinder -d "$DOMAIN" -silent 2>/dev/null | sort -u > "$OUT/subdomains/all_subs.txt"
    echo "$DOMAIN" >> "$OUT/subdomains/all_subs.txt"
    sort -u "$OUT/subdomains/all_subs.txt" -o "$OUT/subdomains/all_subs.txt"
    ok "Subdomains: $(wc -l < "$OUT/subdomains/all_subs.txt")"
}

mod_probing() {
    log "[2] Live Host Probing"
    needs_subs
    httpx -l "$OUT/subdomains/all_subs.txt" -silent -title -tech-detect \
        -status-code -web-server -follow-redirects -timeout 15 \
        -o "$OUT/probing/live_detailed.txt" 2>/dev/null
    awk '{print $1}' "$OUT/probing/live_detailed.txt" | sort -u > "$OUT/probing/live.txt"
    ok "Live hosts: $(wc -l < "$OUT/probing/live.txt")"
}

mod_urls() {
    log "[3] URL Collection"
    needs_live
    cat "$OUT/probing/live.txt" | gau --threads 10 2>/dev/null | sort -u > "$OUT/urls/all_urls.txt"
    cat "$OUT/probing/live.txt" | waybackurls 2>/dev/null | sort -u >> "$OUT/urls/all_urls.txt"
    sort -u "$OUT/urls/all_urls.txt" -o "$OUT/urls/all_urls.txt"
    ok "URLs: $(wc -l < "$OUT/urls/all_urls.txt")"
}

mod_js() {
    log "[4] JS Analysis + Secrets"
    needs_live
    cat "$OUT/probing/live.txt" | katana -d 2 -jc -silent 2>/dev/null \
        | grep -iE '\.js($|\?)' | sort -u > "$OUT/js/js_files.txt"
    > "$OUT/js/js_secrets.txt"
    while read -r js; do
        curl -s -m 10 "$js" 2>/dev/null | \
            grep -oiE "(api[_-]?key|secret|token|password|auth)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{8,}" \
            >> "$OUT/js/js_secrets.txt"
    done < "$OUT/js/js_files.txt"
    sort -u "$OUT/js/js_secrets.txt" -o "$OUT/js/js_secrets.txt"
    ok "JS files: $(wc -l < "$OUT/js/js_files.txt") | Secrets: $(wc -l < "$OUT/js/js_secrets.txt")"
}

mod_nuclei() {
    log "[5] Nuclei — medium+ severity"
    needs_live
    nuclei -l "$OUT/probing/live.txt" -silent -severity medium,high,critical \
        -o "$OUT/exploits/nuclei_medium.txt" 2>/dev/null
    ok "Nuclei findings: $(wc -l < "$OUT/exploits/nuclei_medium.txt" 2>/dev/null || echo 0)"
}

mod_cve() {
    log "[6] Full CVE Sweep (all severities)"
    needs_live
    nuclei -l "$OUT/probing/live.txt" -silent -o "$OUT/exploits/nuclei_full.txt" 2>/dev/null
    ok "Full sweep findings: $(wc -l < "$OUT/exploits/nuclei_full.txt" 2>/dev/null || echo 0)"
}

mod_xss() {
    log "[7] XSS Hunting"
    needs_urls
    cat "$OUT/urls/all_urls.txt" | gf xss 2>/dev/null > "$OUT/exploits/xss_urls.txt"
    cat "$OUT/exploits/xss_urls.txt" | kxss 2>/dev/null | awk '/URL:/ {print $2}' > "$OUT/exploits/xss_reflected.txt"
    cat "$OUT/exploits/xss_reflected.txt" | dalfox pipe --silence -o "$OUT/exploits/xss_dalfox.txt" 2>/dev/null
    ok "XSS candidates: $(wc -l < "$OUT/exploits/xss_reflected.txt" 2>/dev/null || echo 0)"
}

mod_takeover() {
    log "[8] Subdomain Takeover"
    needs_live
    subzy run --targets "$OUT/probing/live.txt" --hide_fails --verify_ssl \
        2>/dev/null > "$OUT/exploits/takeover.txt"
    ok "Takeovers: $(grep -c VULNERABLE "$OUT/exploits/takeover.txt" 2>/dev/null || echo 0)"
}

mod_cors() {
    log "[9] CORS Misconfiguration"
    needs_live
    > "$OUT/exploits/cors.txt"
    while read -r url; do
        acao=$(curl -s -m 8 -H "Origin: https://evil.com" -I "$url" 2>/dev/null \
            | grep -i "access-control-allow-origin")
        echo "$acao" | grep -qi "evil.com" && echo "$url -> $acao" >> "$OUT/exploits/cors.txt"
    done < "$OUT/probing/live.txt"
    ok "CORS issues: $(wc -l < "$OUT/exploits/cors.txt")"
}

mod_admin() {
    log "[10] Admin Panels"
    needs_live
    > "$OUT/exploits/admin_panels.txt"
    while read -r host; do
        for path in admin admin/login administrator dashboard panel wp-admin phpmyadmin; do
            code=$(curl -s -o /dev/null -w "%{http_code}" -m 6 "$host/$path" 2>/dev/null)
            { [ "$code" = "200" ] || [ "$code" = "401" ] || [ "$code" = "403" ]; } && \
                echo "$host/$path [$code]" >> "$OUT/exploits/admin_panels.txt"
        done
    done < "$OUT/probing/live.txt"
    sort -u "$OUT/exploits/admin_panels.txt" -o "$OUT/exploits/admin_panels.txt"
    ok "Admin paths: $(wc -l < "$OUT/exploits/admin_panels.txt")"
}

mod_sensitive() {
    log "[11] Sensitive Files + Git Exposure"
    needs_live
    > "$OUT/exploits/sensitive_files.txt"
    while read -r host; do
        for f in .env .git/config .DS_Store backup.zip db.sql phpinfo.php server-status; do
            code=$(curl -s -o /dev/null -w "%{http_code}" -m 6 "$host/$f" 2>/dev/null)
            [ "$code" = "200" ] && echo "$host/$f [200 EXPOSED]" >> "$OUT/exploits/sensitive_files.txt"
        done
    done < "$OUT/probing/live.txt"
    sort -u "$OUT/exploits/sensitive_files.txt" -o "$OUT/exploits/sensitive_files.txt"
    ok "Exposed files: $(wc -l < "$OUT/exploits/sensitive_files.txt")"
}

mod_graphql() {
    log "[12] GraphQL Introspection"
    needs_live
    > "$OUT/exploits/graphql.txt"
    while read -r host; do
        for ep in graphql graphiql api/graphql v1/graphql; do
            res=$(curl -s -m 8 -X POST -H "Content-Type: application/json" \
                -d '{"query":"{__schema{types{name}}}"}' "$host/$ep" 2>/dev/null)
            echo "$res" | grep -q "__schema" && echo "$host/$ep — INTROSPECTION OPEN" >> "$OUT/exploits/graphql.txt"
        done
    done < "$OUT/probing/live.txt"
    ok "GraphQL issues: $(wc -l < "$OUT/exploits/graphql.txt")"
}

mod_redirect() {
    log "[13] Open Redirect Candidates"
    needs_urls
    cat "$OUT/urls/all_urls.txt" | gf redirect 2>/dev/null > "$OUT/exploits/open_redirects.txt"
    ok "Redirect candidates: $(wc -l < "$OUT/exploits/open_redirects.txt" 2>/dev/null || echo 0)"
}

mod_gf() {
    log "[14] GF Patterns (exploit-ready URLs)"
    needs_urls
    for p in xss sqli ssrf redirect rce lfi; do
        cat "$OUT/urls/all_urls.txt" | gf "$p" > "$OUT/exploits/gf_$p.txt" 2>/dev/null
    done
    ok "GF patterns saved: $OUT/exploits/gf_*.txt"
}

# ================================================================
#   MENU SYSTEM
# ================================================================

run_module() {
    case "$1" in
        1)  mod_subdomains ;;
        2)  mod_probing ;;
        3)  mod_urls ;;
        4)  mod_js ;;
        5)  mod_nuclei ;;
        6)  mod_cve ;;
        7)  mod_xss ;;
        8)  mod_takeover ;;
        9)  mod_cors ;;
        10) mod_admin ;;
        11) mod_sensitive ;;
        12) mod_graphql ;;
        13) mod_redirect ;;
        14) mod_gf ;;
        *)  warn "Unknown module: $1" ;;
    esac
}

show_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << MENU
==================================================
   ReconX v2.0  |  Target: $DOMAIN
==================================================
  [1]  Subdomain Enumeration
  [2]  Live Host Probing
  [3]  URL Collection (gau + wayback)
  [4]  JS Analysis + Secrets
  [5]  Nuclei Scan (medium+)
  [6]  Full CVE Sweep (all severities)
  [7]  XSS Hunting (gf + kxss + dalfox)
  [8]  Subdomain Takeover (subzy)
  [9]  CORS Misconfiguration
  [10] Admin Panels Discovery
  [11] Sensitive Files + Git Exposure
  [12] GraphQL Introspection
  [13] Open Redirect Candidates
  [14] GF Patterns (exploit-ready URLs)
--------------------------------------------------
  [a]  RUN ALL   |   [0] Exit
==================================================
MENU
    echo -e "${NC}"
}

# ---------- MAIN LOOP ----------
while true; do
    show_menu
    read -rp "Select modules (e.g. 1,3,7 | a = all | 0 = exit): " CHOICE

    case "$CHOICE" in
        0)  echo "Output saved: $OUT"; exit 0 ;;
        a|A) for m in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do run_module "$m"; done ;;
        *)
            IFS=',' read -ra PICKS <<< "$CHOICE"
            for p in "${PICKS[@]}"; do
                run_module "$(echo "$p" | tr -d '[:space:]')"
            done
            ;;
    esac

    echo ""
    read -rp "Menu again? (y/n): " CONT
    [[ "$CONT" =~ ^[nN] ]] && { echo "Output saved: $OUT"; break; }
done