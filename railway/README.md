# Deploying to Railway

This folder contains a Railway-specific build that runs the export **and** the Google Drive upload in a single
container, because Railway [Cron Jobs](https://docs.railway.com/cron-jobs) run one service to completion — there's
no built-in way to chain "service A, then service B".

## 1. Create the service

1. In your Railway project, add a new service from this GitHub repo.
2. Railway will pick up [`railway.json`](../railway.json) at the repo root automatically, which points the build
   at [`railway/Dockerfile`](./Dockerfile) and sets a daily cron schedule (`0 16 * * *` UTC = 00:00 Asia/Taipei —
   adjust for your timezone, Railway cron is always UTC).

## 2. Attach a Volume for rclone

OAuth refresh tokens must persist between cron runs. Add a [Volume](https://docs.railway.com/volumes) to this
service with mount path:

```text
/config/rclone
```

The entrypoint writes `rclone.conf` there on first run (seeded from env) and lets rclone update the token in
place on later runs.

## 3. Set environment variables

**Coros credentials** (same as [`.env.example`](../.env.example)):

- `COROS_API_URL`
- `COROS_EMAIL`
- `COROS_PASSWORD`

**rclone / Google Drive** — used once to seed `/config/rclone/rclone.conf` on the volume. After a successful
run you can leave them set (the entrypoint ignores them in favour of the file) or remove
`RCLONE_CONFIG_GDRIVE_TOKEN` to avoid keeping a stale copy in Railway:

- `RCLONE_CONFIG_GDRIVE_TYPE=drive` — optional once the volume is seeded; only needed for bootstrap
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
- `RCLONE_REBOOTSTRAP=1` — force overwrite of the volume's `rclone.conf` from the env vars above (use after
  re-authorizing Google when you hit `unauthorized_client` / `invalid_grant`). Unset it again after one
  successful run.

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

If the Google OAuth client or refresh token later becomes invalid, re-run the flow above, update the Railway
env vars, set `RCLONE_REBOOTSTRAP=1` for one run, then remove that flag.

## 4. Trigger a manual run to verify

In the Railway service, use "Deploy" / the manual trigger option to run it once outside the cron schedule and
check the logs before waiting for the first scheduled run. You should see a line about writing `rclone.conf`
to the volume on the first successful bootstrap.
