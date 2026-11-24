## Description

Shared library for page publish features (snapshot payloads, SSR helpers, shared schemas, and storage contracts).

The Cloudflare Durable Object implementation is expected to use SQLite with the
Logseq datascript fork layered on top. Page publish payloads are expected to
send datoms (transit) so the DO can reconstruct/query datascript state.

See `deps/publish/worker` for a Cloudflare Worker skeleton that stores transit
blobs in R2 and metadata in a SQLite-backed Durable Object.

## API

Namespaces live under `logseq.publish`.

## Usage

This module is intended to be consumed by the Logseq app and the publish worker.

## Dev

Keep this module aligned with the main repo's linting and testing conventions.
Most of the same linters are used, with configurations that are specific to this
library. See [this library's CI file](/.github/workflows/deps-publish.yml) for
linting examples.


### Local Testing

For one-time setup, install the [CloudFlare cli wrangler](https://developers.cloudflare.com/workers/wrangler/) with `npm install -g wrangler@latest`.

To test the publish features locally, follow these steps:

* Run `pnpm watch` or `pnpm release` to build the publish worker js asset.
* Run `wrangler dev` in worker/ to start a local cloudflare worker server.
* In the desktop app, set Settings → Publish Server URL to the localhost url.
* Sign in on the desktop app.
* Go to any page and select `Publish` from its page menu.

### Self-hosted (Node.js)

`logseq.publish.node.server` runs the same routes on Node.js: metadata in
SQLite (`meta.sqlite`), page payloads and assets as files (`objects/`).

```bash
pnpm build:node && pnpm build:static
AUTH_ISSUER=... AUTH_CLIENT_ID=... AUTH_JWKS_URL=... PUBLISH_DATA_DIR=data/publish pnpm start:node
```

It listens on `PUBLISH_PORT` (default 8788). The `AUTH_*` values are the
sync server's (`deps/db-sync/scripts/selfhost-token.mjs env`). It also
serves `worker/dist/static/` (fonts, KaTeX, CodeMirror, emoji data, collected
by `pnpm build:static`) under `/static/`; the Cloudflare Worker has no such
files. Docker setup: `docker/publish/`.

### Deploy

When changes are ready to be deployed, run `pnpm deploy`.