#!/usr/bin/env bash
# ==============================================================================
# rIDM Database Automated Backup Script
# Creates compressed, timestamped dumps of the 'ridm' PostgreSQL database
# ==============================================================================
set -euo pipefail

BACKUP_DIR="/home/server/backups/ridm"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/ridm_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=14

mkdir -p "${BACKUP_DIR}"

echo "[$(date -Iseconds)] Starting backup of rIDM database..."

docker exec ridm-postgres pg_dump -U ridm -d ridm | gzip > "${BACKUP_FILE}"

FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[$(date -Iseconds)] Backup completed successfully: ${BACKUP_FILE} (${FILE_SIZE})"

# Prune backups older than RETENTION_DAYS
echo "[$(date -Iseconds)] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "ridm_backup_*.sql.gz" -mtime +"${RETENTION_DAYS}" -exec rm -f {} \;

echo "[$(date -Iseconds)] Done."
