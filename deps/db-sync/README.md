# Logseq DB Sync (deps/db-sync)

This package contains the DB sync server code and tests used by Logseq.
It includes the Cloudflare Worker implementation and a Node.js adapter for self-hosting.

The self-hosted server is the Node.js adapter, deployed with Docker and Caddy:
see `../../docker/db-sync/README.md`. `worker/wrangler.toml` is set up for local
Cloudflare development only (no deploy environments); set your own D1 database
and R2 bucket there before a Cloudflare deploy.

## Requirements
- Node.js (see repo root for required version)
- Clojure (for shadow-cljs builds)

## Build and Test

### Cloudflare Worker

```bash
cd deps/db-sync
pnpm watch

# open another terminal
cd deps/db-sync/worker
wrangler dev
```

### D1 Schema (Worker)

The worker no longer initializes schema at request time. Apply the D1 schema
via migrations: for local development, run `pnpm migrate:local`
(`wrangler d1 migrations apply DB --local`).

### Graph Lookup (D1)

Show the graphs available to a user by `username` or `user id`:

```bash
cd deps/db-sync
pnpm show-graphs-for-user --username alice
pnpm show-graphs-for-user --user-id us-east-1:example-user-id
```

The D1 scripts (`show-graphs-for-user`, `show-usage-stats`, `delete-graphs-for-user`,
`delete-user-totally`) use `worker/wrangler.toml` and the D1 binding `DB`. They
default to `--env local` (the local D1 database of `wrangler dev`); another
`--env <env>` runs against that remote environment. They print JSON when
`--json` is added. They do not read the Node adapter's SQLite index.

Show usage totals (total users, total graphs, users created today, graphs created today):

```bash
cd deps/db-sync
pnpm show-usage-stats
pnpm show-usage-stats --days 7
pnpm show-usage-stats --json
```

`created today` uses UTC day boundaries from D1 (`date('now')`).
`active_*_last_n_days` uses deduplicated UTC-day activity rows from
`daily_active_entities` with the provided `--days` window.

Download a graph snapshot into a local sqlite debug file matching local graph DB schema (`kvs` table only):

```bash
cd deps/db-sync
pnpm run download-graph-db -- --graph-id 6f2d7f6f-xxxx-xxxx-xxxx-xxxxxxxxxxxx --admin-token <admin-token>
```

The sync server URL is required: pass `--base-url <url>` or set `DB_SYNC_BASE_URL`.
You can also pass `--admin-token <token>` or set `DB_SYNC_ADMIN_TOKEN`. The output defaults to
`tmp/graph-<graph-id>.snapshot.sqlite` and can be changed with `--output`.

Show stored and recomputed checksum for a local sqlite graph db:

```bash
cd deps/db-sync
pnpm run show-sqlite-checksum -- --db ~/Downloads/test.sqlite
```

Delete the graphs owned by a user after an explicit confirmation:

```bash
cd deps/db-sync
pnpm delete-graphs-for-user --username alice
pnpm delete-graphs-for-user --user-id us-east-1:example-user-id
```

The delete script shows the owned graphs first and requires typing `DELETE`
before it calls the worker delete endpoint for each graph. Set
`DB_SYNC_BASE_URL` and `DB_SYNC_ADMIN_TOKEN` or pass `--base-url` and
`--admin-token` when running it.

Delete a user completely (owned graphs, memberships, keys, and user row):

```bash
cd deps/db-sync
pnpm run delete-user-totally -- --username alice
pnpm run delete-user-totally -- --user-id us-east-1:example-user-id
```

The script prints all linked graphs first, deletes owned graphs through the
admin graph delete endpoint, then removes the user's remaining D1 references.
It requires typing `DELETE` as confirmation.

### Node.js Adapter (self-hosted)

Build the adapter:

```bash
cd deps/db-sync
pnpm build:node-adapter
```

Run the adapter with self-issued sign-in tokens. `scripts/selfhost-token.mjs init <dir> --issuer <url> --username <name>` prints the three `AUTH_*` values; `token <dir>` prints a token for the apps (`logseq login --token <token>` for the CLI):

```bash
DB_SYNC_PORT=8787 \
AUTH_ISSUER=... AUTH_CLIENT_ID=... AUTH_JWKS_URL=... \
node worker/dist/node-adapter.js
```

### Tests

Run db-sync tests (includes Node adapter tests):

```bash
cd deps/db-sync
pnpm test:node-adapter
```

## Environment Variables

| Variable | Purpose |
| --- | --- |
| DB_SYNC_PORT | HTTP server port |
| DB_SYNC_BASE_URL | External base URL for asset links |
| DB_SYNC_ADMIN_TOKEN | Admin-only token (header `x-db-sync-admin-token`): passes the graph access check on sync and asset routes, and the operator graph deletion endpoints |
| DB_SYNC_DATA_DIR | Data directory for sqlite + assets |
| DB_SYNC_STORAGE_DRIVER | Storage backend selection (sqlite) |
| DB_SYNC_ASSETS_DRIVER | Assets backend selection (filesystem) |
| AUTH_ISSUER | Sign-in token issuer (`iss`) |
| AUTH_CLIENT_ID | Sign-in token audience (`aud` / `client_id`) |
| AUTH_CLIENT_IDS | Optional extra accepted client ids, comma separated |
| AUTH_JWKS_URL | JWKS URL with the token signing keys (a `data:` URL works) |

## Notes
- Runtime and db-sync engineering guidance is consolidated in `../../docs/agent-guide/implemented/architecture/2026-08-24-logseq-runtime-and-engineering-guide.md`; current protocol and route definitions live under `src/logseq/db_sync/worker/`.
