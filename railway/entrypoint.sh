#!/bin/sh
# Entrypoint for the Railway Cron Job service: export activities, upload the
# result to Google Drive, then clean up. Exits non-zero on failure so Railway
# marks the run as failed.
set -eu

EXPORT_DIR="/tmp/export"
DRIVE_REMOTE="${DRIVE_REMOTE:-gdrive:coros-exports}"
# Only re-fetch a recent window instead of the full history every run.
# A few days of overlap is a cheap safety net against a missed/failed run;
# rclone copy skips files already on Drive, so overlap is free.
LOOKBACK_DAYS="${LOOKBACK_DAYS:-3}"

# Persist rclone.conf (incl. refreshed OAuth tokens) on a Railway Volume
# mounted at /config/rclone. Env vars only seed the file on first run.
RCLONE_CONFIG_DIR="/config/rclone"
RCLONE_CONFIG="${RCLONE_CONFIG:-$RCLONE_CONFIG_DIR/rclone.conf}"
export RCLONE_CONFIG
mkdir -p "$RCLONE_CONFIG_DIR"

bootstrap_rclone_conf() {
  if [ -z "${RCLONE_CONFIG_GDRIVE_TOKEN:-}" ]; then
    echo "ERROR: $RCLONE_CONFIG missing and RCLONE_CONFIG_GDRIVE_TOKEN is unset; cannot bootstrap." >&2
    exit 1
  fi
  echo "[$(date -Iseconds)] Writing rclone.conf to volume from env..."
  # token is a JSON object; write it on one line as rclone expects.
  cat > "$RCLONE_CONFIG" <<EOF
[gdrive]
type = drive
client_id = ${RCLONE_CONFIG_GDRIVE_CLIENT_ID:-}
client_secret = ${RCLONE_CONFIG_GDRIVE_CLIENT_SECRET:-}
scope = ${RCLONE_CONFIG_GDRIVE_SCOPE:-drive}
token = ${RCLONE_CONFIG_GDRIVE_TOKEN}
EOF
}

if [ "${RCLONE_REBOOTSTRAP:-0}" = "1" ] || [ ! -f "$RCLONE_CONFIG" ]; then
  bootstrap_rclone_conf
fi

# Env remotes override the config file. Unset them so the volume-backed file
# (with refreshed tokens) wins on every run after bootstrap.
unset RCLONE_CONFIG_GDRIVE_TYPE \
  RCLONE_CONFIG_GDRIVE_CLIENT_ID \
  RCLONE_CONFIG_GDRIVE_CLIENT_SECRET \
  RCLONE_CONFIG_GDRIVE_SCOPE \
  RCLONE_CONFIG_GDRIVE_TOKEN

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
