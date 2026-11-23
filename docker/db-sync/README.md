# Self-hosted sync server

Runs the Logseq DB sync server (`deps/db-sync`, Node.js adapter) behind
Caddy, which serves HTTPS with an automatic Let's Encrypt certificate.
Sign-in uses self-issued tokens, no Logseq account.

The image is built from this repository checkout, so the server runs the
same code as apps built from the same commit.

## Requirements

- A host with Docker and Docker Compose, about 2 GB of RAM for the build
  (the ClojureScript compile may fail on a 1 GB VPS).
- A domain with an A/AAAA record pointing to the host; ports 80 and 443 open.
- Node.js on the machine where you issue tokens (any machine; the private
  key never goes to the server).

## Deploy

1. Clone the fork on the host and check out your branch:

   ```bash
   git clone -b <branch> https://github.com/newparadigma/logseq.git
   cd logseq/docker/db-sync
   ```

2. Create the sign-in key and the server settings (on a trusted machine):

   ```bash
   node deps/db-sync/scripts/selfhost-token.mjs init ~/logseq-sync-auth --issuer https://sync.example.com/ --username me
   ```

   It prints three `AUTH_*` lines. Keep `~/logseq-sync-auth` private:
   whoever has `private.pem` can sign in as you.

3. `cp .env.example .env`, then set `DOMAIN`, `DATA_DIR`, `PUID`/`PGID`
   and paste the three `AUTH_*` lines.

4. Start:

   ```bash
   docker compose up -d --build
   ```

   Check: `curl https://sync.example.com/health`.

5. Issue a token for the apps:

   ```bash
   node deps/db-sync/scripts/selfhost-token.mjs token ~/logseq-sync-auth
   ```

   In the app: Settings → Sync Server URL → `https://sync.example.com`,
   then paste the token and sign in. CLI (see `docs/cli/logseq-cli.md`):

   ```bash
   logseq sync config set http-base https://sync.example.com
   logseq sync config set ws-url 'wss://sync.example.com/sync/%s'
   logseq login --token <token>
   ```

## Update

```bash
git pull
docker compose up -d --build
```

## Data

- `DATA_DIR/index.sqlite`, `DATA_DIR/graphs/<id>/db.sqlite`,
  `DATA_DIR/assets/`. Back up `DATA_DIR`.
- `./caddy/` holds the TLS certificates; it can be deleted, Caddy then
  requests new ones.
- Revoke all tokens: run `init` in a new folder, put the new `AUTH_*` lines
  into `.env`, `docker compose up -d`. The server may accept a cached old
  key for up to 1 hour.
