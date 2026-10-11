#!/usr/bin/env bash
# ==============================================================================
# rIDM User Unlock & Account Recovery Helper
# Usage: 
#   ridm-unlock <username_or_email>
#   ridm-unlock --list
# ==============================================================================

set -euo pipefail

DB_CONTAINER="ridm-postgres"
VALKEY_CONTAINER="ridm-valkey"

if [ $# -eq 0 ]; then
  echo "Penggunaan:"
  echo "  ridm-unlock <username_atau_email>   # Membuka kunci user"
  echo "  ridm-unlock --list                  # Melihat daftar user yang sedang terkunci / gagal login"
  exit 1
fi

if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
  echo "[*] Mencari akun yang sedang terkunci atau memiliki riwayat gagal login..."
  docker exec -i "$DB_CONTAINER" psql -U ridm -d ridm -c "
  SET app.bypass_rls = 'on';
  SELECT u.id, u.username, u.email, u.failed_attempts, u.locked_until, u.status, t.slug as tenant
  FROM users u
  JOIN tenants t ON u.tenant_id = t.id
  WHERE u.locked_until > now() OR u.status = 'locked' OR u.failed_attempts > 0;
  "
  exit 0
fi

TARGET="$1"
TARGET_LOWER=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')

echo "[*] Memeriksa akun: $TARGET_LOWER..."

# 1. Cek status akun saat ini
EXISTING=$(docker exec -i "$DB_CONTAINER" psql -U ridm -d ridm -t -A -c "
SET app.bypass_rls = 'on';
SELECT u.id || '|' || u.username || '|' || coalesce(u.email, '-') || '|' || u.failed_attempts || '|' || coalesce(u.locked_until::text, 'tidak terkunci') || '|' || u.status || '|' || u.tenant_id
FROM users u
WHERE lower(u.username) = '$TARGET_LOWER' OR lower(u.email) = '$TARGET_LOWER'
LIMIT 1;
" 2>/dev/null | grep -v '^SET$' || true)

if [ -z "$EXISTING" ]; then
  echo "[-] Akun '$TARGET' tidak ditemukan di database rIDM."
  exit 1
fi

IFS='|' read -r USER_ID USERNAME EMAIL FAILED_ATTEMPTS LOCKED_UNTIL STATUS TENANT_ID <<< "$EXISTING"

echo "[i] Detail Akun:"
echo "    - ID: $USER_ID"
echo "    - Username: $USERNAME"
echo "    - Email: $EMAIL"
echo "    - Failed Attempts: $FAILED_ATTEMPTS"
echo "    - Locked Until: $LOCKED_UNTIL"
echo "    - Status: $STATUS"

# 2. Reset status dan lockout di PostgreSQL
echo "[*] Mereset status akun dan membuka kunci..."
docker exec -i "$DB_CONTAINER" psql -U ridm -d ridm -c "
SET app.bypass_rls = 'on';
UPDATE users
SET failed_attempts = 0,
    locked_until = NULL,
    status = 'active',
    updated_at = now()
WHERE id = '$USER_ID';
" >/dev/null

# 3. Hapus cache di Valkey jika ada
if docker ps --format '{{.Names}}' | grep -q "^$VALKEY_CONTAINER$"; then
  docker exec -i "$VALKEY_CONTAINER" valkey-cli --scan --pattern "ridm:t:${TENANT_ID}:user:${USER_ID}:*" | while read -r KEY; do
    [ -n "$KEY" ] && docker exec -i "$VALKEY_CONTAINER" valkey-cli del "$KEY" >/dev/null || true
  done
fi

echo "[✓] Sukses! Akun '$USERNAME' telah dibuka kuncinya dan statusnya aktif kembali."
echo "    Pegawai sekarang sudah bisa langsung login kembali tanpa menunggu 15 menit."
