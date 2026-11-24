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
- Your Mac (or another trusted machine) with Node.js and this repository:
  sign-in keys and tokens are made there. The server needs no Node.js, and
  the private key never goes to it.

## Deploy

Steps 1, 3 and 4 run on the server, steps 2 and 5 on your Mac.

1. Server: clone the fork and check out your branch. The user that runs
   Docker (in the `docker` group) should own the checkout:

   ```bash
   git clone -b <branch> https://github.com/newparadigma/logseq.git
   cd logseq/docker/db-sync
   ```

2. Mac, from the repository root: create the sign-in key once and print
   the server settings:

   ```bash
   node deps/db-sync/scripts/selfhost-token.mjs init ~/logseq-sync-auth --issuer https://sync.example.com/ --username me
   ```

   It prints three `AUTH_*` lines (`node deps/db-sync/scripts/selfhost-token.mjs env ~/logseq-sync-auth`
   prints them again). Keep `~/logseq-sync-auth` private: whoever has
   `private.pem` can sign in as you.

3. Server: `cp .env.example .env` and `chmod 600 .env`, then set `DOMAIN`,
   `DATA_DIR` (outside the checkout), `PUID`/`PGID` (`id -u`, `id -g` of the
   Docker user) and paste the three `AUTH_*` lines.

4. Server: start:

   ```bash
   docker compose up -d --build
   ```

   Check: `curl https://sync.example.com/health`.

5. Mac, from the repository root: issue a token for the apps:

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
