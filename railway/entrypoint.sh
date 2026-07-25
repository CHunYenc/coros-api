#!/bin/sh
# Entrypoint for the Railway Cron Job service: export activities, upload the
# result to Google Drive, then clean up. Exits non-zero on failure so Railway
# marks the run as failed.
set -eu

EXPORT_DIR="/tmp/export"
DRIVE_REMOTE="${DRIVE_REMOTE:-gdrive:coros-exports}"

mkdir -p "$EXPORT_DIR"

echo "[$(date -Iseconds)] Exporting activities to $EXPORT_DIR..."
node dist/main export-activities --out "$EXPORT_DIR"

echo "[$(date -Iseconds)] Uploading to $DRIVE_REMOTE..."
rclone copy "$EXPORT_DIR" "$DRIVE_REMOTE" -v

echo "[$(date -Iseconds)] Cleaning up..."
rm -rf "${EXPORT_DIR:?}"/*

echo "[$(date -Iseconds)] Done."
