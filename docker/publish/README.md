# Self-hosted publish server

Runs the Logseq page publish server (`deps/publish`, Node.js adapter) behind
Caddy, which serves HTTPS with an automatic Let's Encrypt certificate.
Publishing uses the same self-issued sign-in tokens as the self-hosted sync
server (`docker/db-sync`), no Logseq account.

The image is built from this repository checkout, so pages are rendered
with the same code as apps built from the same commit.

## Requirements

- A host with Docker and Docker Compose, about 2 GB of RAM for the build.
- A domain of its own with an A/AAAA record pointing to the host, for
  example `publish.example.com`. The server cannot share the sync server's
  domain: both use paths such as `/assets`.
- The sign-in key from the sync server setup (`~/logseq-sync-auth` on your
  Mac, see `docker/db-sync/README.md`).

## Deploy

1. Server: in the repository checkout, `cd docker/publish`.

2. Server: `cp .env.example .env` and `chmod 600 .env`, then set
   `PUBLISH_DOMAIN`, `DATA_DIR` (outside the checkout), `PUID`/`PGID`
   (`id -u`, `id -g` of the Docker user) and paste the three `AUTH_*` lines
   from the sync server's `.env`. On your Mac, from the repository root,
   `node deps/db-sync/scripts/selfhost-token.mjs env ~/logseq-sync-auth`
   prints them again.

3. Server: start:

   ```bash
   docker compose up -d --build
   ```

   Check: `curl -I https://publish.example.com/`.

4. In the app: Settings → Publish Server URL → `https://publish.example.com`.
   Publishing sends the token you signed in to the sync server with.
   Then use "Publish" in a page menu.

## Same host as the sync server

Both stacks start a Caddy on ports 80 and 443, so only one of them can run.
Use the sync server's Caddy for both domains:

1. Add a block for the publish domain to `docker/db-sync/Caddyfile`:

   ```
   publish.example.com {
   	reverse_proxy logseq-publish:8788
   }
   ```

2. Here, create `docker-compose.override.yml` (gitignored), which puts the
   server on the sync stack's network, so that its Caddy reaches it by the
   name `logseq-publish`:

   ```yaml
   services:
     logseq-publish:
       networks: [db-sync]
   networks:
     db-sync:
       name: db-sync_default
       external: true
   ```

3. Start only the server here, then restart the sync stack's Caddy:

   ```bash
   docker compose up -d --build logseq-publish
   cd ../db-sync && docker compose restart caddy
   ```

   On updates, also start only `logseq-publish`.

## Update

```bash
git pull
docker compose up -d --build
```

## Data

- `DATA_DIR/meta.sqlite` (published pages, references, tags, search),
  `DATA_DIR/objects/publish/<graph>/<hash>.transit` (page contents),
  `DATA_DIR/objects/publish/assets/<graph>/` (images and other assets).
  Back up `DATA_DIR`.
- Unpublishing a page removes it from `meta.sqlite` only; its `.transit`
  file and assets stay in `objects/`.
- `./caddy/` holds the TLS certificates; it can be deleted, Caddy then
  requests new ones.
- Published pages load fonts and scripts from public CDNs (`cdn.jsdelivr.net`,
  `esm.sh`), so visitors' browsers contact them.
