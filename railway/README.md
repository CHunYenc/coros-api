# Deploying to Railway

This folder contains a Railway-specific build that runs the export **and** the Google Drive upload in a single
container, because Railway [Cron Jobs](https://docs.railway.com/cron-jobs) run one service to completion — there's
no built-in way to chain "service A, then service B".

## 1. Create the service

1. In your Railway project, add a new service from this GitHub repo.
2. Railway will pick up [`railway.json`](../railway.json) at the repo root automatically, which points the build
   at [`railway/Dockerfile`](./Dockerfile) and sets a daily cron schedule (`0 19 * * *` UTC = 03:00 Asia/Taipei —
   adjust for your timezone, Railway cron is always UTC).

## 2. Set environment variables

**Coros credentials** (same as [`.env.example`](../.env.example)):

- `COROS_API_URL`
- `COROS_EMAIL`
- `COROS_PASSWORD`

**rclone / Google Drive**, using rclone's [environment variable config](https://rclone.org/docs/#environment-variables)
instead of a mounted `rclone.conf` file (Railway has no persistent host file to mount):

- `RCLONE_CONFIG_GDRIVE_TYPE=drive`
- `RCLONE_CONFIG_GDRIVE_CLIENT_ID` — your Google OAuth client ID (recommended: use your own, not rclone's shared one)
- `RCLONE_CONFIG_GDRIVE_CLIENT_SECRET` — the matching client secret
- `RCLONE_CONFIG_GDRIVE_SCOPE=drive`
- `RCLONE_CONFIG_GDRIVE_TOKEN` — the OAuth token JSON (see below)

Optional:

- `DRIVE_REMOTE` — defaults to `gdrive:coros-exports`, override to change the target remote/folder.
- `LOOKBACK_DAYS` — defaults to `3`. Each run only exports activities from the last N days (via `--fromDate`/
  `--toDate`) instead of your full history, since the job runs daily. The default gives a couple of days of
  overlap as a safety net in case a run is missed or fails — `rclone copy` skips files already on Drive, so the
  overlap doesn't cause duplicate uploads, just a bit of re-fetching from the Coros API.

### Generating `RCLONE_CONFIG_GDRIVE_TOKEN`

Run `rclone config` once on any machine (e.g. your laptop) to complete the Google OAuth flow and create a remote
named `gdrive`:

```shell
docker run --rm -it -v "$PWD/rclone.conf:/config/rclone/rclone.conf" rclone/rclone config
```

Then print the config and copy the `token` field's JSON value into the `RCLONE_CONFIG_GDRIVE_TOKEN` variable:

```shell
docker run --rm -v "$PWD/rclone.conf:/config/rclone/rclone.conf" rclone/rclone config show gdrive
```

rclone automatically refreshes the token as needed and Railway persists env var changes, but the refresh token
only lives in memory during each run — if it rotates, update the variable, or switch to a Railway
[Volume](https://docs.railway.com/volumes) mounted at `/config/rclone` and let rclone manage `rclone.conf` there
instead of using env vars.

## 3. Trigger a manual run to verify

In the Railway service, use "Deploy" / the manual trigger option to run it once outside the cron schedule and
check the logs before waiting for the first scheduled run.
