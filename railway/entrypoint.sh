#!/bin/sh
# Entrypoint for the Railway Cron Job service: export activities, upload the
# result to Google Drive, then clean up. Exits non-zero on failure so Railway
# marks the run as failed.
set -eu

EXPORT_DIR="/tmp/export"
DRIVE_REMOTE="${DRIVE_REMOTE:-gdrive:coros-exports}"
# Only re-fetch a recent window instead of the full history every run.
# A few days of overlap is a cheap safety net against a missed/failed run;
# rclone copy skips files that are already uploaded, so overlap is free.
LOOKBACK_DAYS="${LOOKBACK_DAYS:-3}"

mkdir -p "$EXPORT_DIR"

FROM_DATE="$(date -u -d "-${LOOKBACK_DAYS} days" +%Y-%m-%d)"
TO_DATE="$(date -u +%Y-%m-%d)"

echo "[$(date -Iseconds)] Exporting activities from $FROM_DATE to $TO_DATE into $EXPORT_DIR..."
node dist/main export-activities --fromDate "$FROM_DATE" --toDate "$TO_DATE" --out "$EXPORT_DIR"

echo "[$(date -Iseconds)] Uploading to $DRIVE_REMOTE..."
rclone copy "$EXPORT_DIR" "$DRIVE_REMOTE" -v

echo "[$(date -Iseconds)] Cleaning up..."
rm -rf "${EXPORT_DIR:?}"/*

echo "[$(date -Iseconds)] Done."
