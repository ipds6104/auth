#!/usr/bin/env bash
# ==============================================================================
# Cloudflare WAF & Anti-Bruteforce Automator
# Zone: dvlpid.my.id (Zone ID: 123190f67c520af731658917b1df61d3)
# ==============================================================================

set -euo pipefail

ZONE_ID="123190f67c520af731658917b1df61d3"

# 1. Cek ketersediaan token Cloudflare (dari argumen, env, atau Infisical)
CF_TOKEN="${1:-${CLOUDFLARE_API_TOKEN:-}}"

if [ -z "$CF_TOKEN" ]; then
  # Coba ambil dari Infisical jika ada
  if command -v infisical-get >/dev/null 2>&1; then
    CF_TOKEN="$(infisical-get CLOUDFLARE_API_TOKEN 2>/dev/null || true)"
  fi
fi

if [ -z "$CF_TOKEN" ]; then
  echo "[-] Cloudflare API Token tidak ditemukan."
  echo "    Penggunaan: $0 <CLOUDFLARE_API_TOKEN>"
  echo "    Atau set: export CLOUDFLARE_API_TOKEN='...'"
  echo "    (Token butuh permission: Zone - Zone:Read, Zone - WAF:Edit)"
  exit 1
fi

echo "[*] Memverifikasi token Cloudflare..."
VERIFY_RES=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "https://api.cloudflare.com/client/v4/user/tokens/verify")
if ! echo "$VERIFY_RES" | grep -q '"status":"active"'; then
  echo "[-] Token tidak valid atau tidak aktif:"
  echo "$VERIFY_RES"
  exit 1
fi
echo "[+] Token valid dan aktif!"

# 2. Pasang Custom Firewall Rules (Managed Challenge untuk non-ID & High Threat Score pada auth.dvlpid.my.id)
echo "[*] Menerapkan WAF Custom Rule (Geo & Threat Challenge untuk auth.dvlpid.my.id)..."
CUSTOM_RULE_PAYLOAD=$(cat <<EOF
{
  "rules": [
    {
      "action": "managed_challenge",
      "expression": "(http.host eq \"auth.dvlpid.my.id\" and (ip.geoip.country ne \"ID\" or cf.threat_score gt 10))",
      "description": "Protect SSO: Managed Challenge non-Indonesia & Threat Score > 10"
    }
  ]
}
EOF
)

CUSTOM_RES=$(curl -s -X PUT \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/phases/http_request_firewall_custom/entrypoint" \
  -d "$CUSTOM_RULE_PAYLOAD")

if echo "$CUSTOM_RES" | grep -q '"success":true'; then
  echo "[+] Berhasil memasang WAF Custom Challenge Rule!"
else
  echo "[!] Respon Custom Rule: $CUSTOM_RES"
fi

# 3. Pasang WAF Rate Limiting Rule (Max 10 POST/menit untuk login & auth endpoints)
echo "[*] Menerapkan WAF Rate Limiting Rule..."
RATELIMIT_PAYLOAD=$(cat <<EOF
{
  "rules": [
    {
      "action": "block",
      "ratelimit": {
        "characteristics": ["cf.colo.id", "ip.src"],
        "period": 60,
        "requests_per_period": 10,
        "mitigation_timeout": 600
      },
      "expression": "(http.host eq \"auth.dvlpid.my.id\" and http.request.method eq \"POST\")",
      "description": "Anti-Bruteforce: Max 10 POST per minute per IP on auth.dvlpid.my.id"
    }
  ]
}
EOF
)

RATELIMIT_RES=$(curl -s -X PUT \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/phases/http_ratelimit/entrypoint" \
  -d "$RATELIMIT_PAYLOAD")

if echo "$RATELIMIT_RES" | grep -q '"success":true'; then
  echo "[+] Berhasil memasang WAF Rate Limiting Rule!"
else
  echo "[!] Respon Rate Limiting: $RATELIMIT_RES"
fi

echo "[✓] Selesai! Proteksi Cloudflare WAF telah diterapkan."
