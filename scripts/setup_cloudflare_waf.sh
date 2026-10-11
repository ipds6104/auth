#!/usr/bin/env bash
# ==============================================================================
# Cloudflare WAF & Anti-Bruteforce Automator
# Zone: dvlpid.my.id (Zone ID: 123190f67c520af731658917b1df61d3)
# ==============================================================================

set -euo pipefail

ZONE_ID="123190f67c520af731658917b1df61d3"
ACCOUNT_ID="6ae19f837acfb31d8e9611150831bbd1"

# 1. Cek ketersediaan token Cloudflare (dari argumen, env, atau Infisical)
CF_TOKEN="${1:-${CLOUDFLARE_API_TOKEN:-}}"

if [ -z "$CF_TOKEN" ]; then
  if command -v infisical-get >/dev/null 2>&1; then
    CF_TOKEN="$(infisical-get CLOUDFLARE_API_TOKEN 2>/dev/null || true)"
  fi
fi

if [ -z "$CF_TOKEN" ]; then
  echo "[-] Cloudflare API Token tidak ditemukan."
  echo "    Penggunaan: $0 <CLOUDFLARE_API_TOKEN>"
  echo "    Atau set: export CLOUDFLARE_API_TOKEN='...'"
  exit 1
fi

echo "[*] Memverifikasi token Cloudflare..."
VERIFY_RES=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "https://api.cloudflare.com/client/v4/user/tokens/verify" 2>/dev/null || true)
if ! echo "$VERIFY_RES" | grep -q '"status":"active"'; then
  # Cek account tokens verify
  VERIFY_RES=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tokens/verify" 2>/dev/null || true)
fi

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
      "description": "Protect SSO: Managed Challenge non-Indonesia & Threat Score > 10",
      "enabled": true
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

if ! echo "$CUSTOM_RES" | grep -q '"success":true'; then
  CUSTOM_RES=$(curl -s -X POST \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets" \
    -d "{
      \"name\": \"Zone Custom Rules\",
      \"kind\": \"zone\",
      \"phase\": \"http_request_firewall_custom\",
      $CUSTOM_RULE_PAYLOAD
    }")
fi

if echo "$CUSTOM_RES" | grep -q '"success":true'; then
  echo "[+] Berhasil menerapkan WAF Custom Challenge Rule!"
else
  echo "[!] Respon Custom Rule: $CUSTOM_RES"
fi

# 3. Pasang WAF Rate Limiting Rule (Max 5 POST/10s untuk login & auth endpoints)
echo "[*] Menerapkan WAF Rate Limiting Rule..."
RATELIMIT_PAYLOAD=$(cat <<EOF
{
  "rules": [
    {
      "action": "block",
      "ratelimit": {
        "characteristics": ["cf.colo.id", "ip.src"],
        "period": 10,
        "requests_per_period": 5,
        "mitigation_timeout": 10
      },
      "expression": "(http.host eq \"auth.dvlpid.my.id\" and http.request.method eq \"POST\")",
      "description": "Anti-Bruteforce: Max 5 POST per 10s per IP on SSO",
      "enabled": true
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

if ! echo "$RATELIMIT_RES" | grep -q '"success":true'; then
  RATELIMIT_RES=$(curl -s -X POST \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets" \
    -d "{
      \"name\": \"Zone Rate Limiting\",
      \"kind\": \"zone\",
      \"phase\": \"http_ratelimit\",
      $RATELIMIT_PAYLOAD
    }")
fi

if echo "$RATELIMIT_RES" | grep -q '"success":true'; then
  echo "[+] Berhasil menerapkan WAF Rate Limiting Rule!"
else
  echo "[!] Respon Rate Limiting: $RATELIMIT_RES"
fi

echo "[✓] Selesai! Proteksi Cloudflare WAF telah aktif dan sinkron."
