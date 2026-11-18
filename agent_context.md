# Agent context: personal Logseq fork

## Goal
- Personal, long-lived fork of Logseq **2.0.2** (DB version). Own development line; no plans to follow upstream updates.
- Personal use only: fix bugs and add features.
- Targets, in order: **macOS desktop app + self-hosted sync server** first; iOS and Android later.

## Status (as of 2026-11-18)
- Done: a Docker setup for the sync server (Dockerfile, docker-compose.yml with Caddy). It was built and smoke-tested in a Linux sandbox (see "Sync server" below).
- Not done yet: the GitHub fork of `logseq/logseq` and the personal branch, the macOS build (needs a Mac; never built so far), and vendoring of the git dependencies.
- Suggested next steps:
  1. The user forks `logseq/logseq` and creates the branch `personal` from tag `2.0.2`.
  2. Vendor the git dependencies into the fork (optional; see below).
  3. Build the unsigned macOS app.
  4. Point the server's `.env` at the fork and the `personal` branch.

## License and repositories
- `logseq/logseq` is **AGPL-3.0** (`LICENSE.md`); `libs/cljs-sdk` is MIT. Private modification and use carry no obligations.
- AGPL obligations start only when sharing: giving builds to others, or letting others use a modified sync server over the network (section 13 → offer them the source).
- The trademark (name and logo) is not covered by the license; it only matters if builds are ever distributed.
- Everything needed lives in the monorepo `logseq/logseq`:
  - desktop app (Electron);
  - iOS and Android apps (Capacitor; `ios/`, `android/`, `capacitor.config.ts`);
  - sync server `deps/db-sync`;
  - core libraries (`deps/common`, `db`, `outliner`, `graph-parser`, ...);
  - CLI.
- Do NOT base work on `logseq/mobile`: it is a separate native SwiftUI/Kotlin/OCaml app with **no license**.
- `logseq/og` is the old file-based (Markdown) version, AGPL; not needed.

### Git dependencies at tag 2.0.2 (pinned by SHA in deps.edn files)
| Repo | License | Pinned commit on default branch? |
|---|---|---|
| logseq/datascript | EPL-1.0 | yes |
| logseq/hsx | Apache-2.0 | **no**, branch `logseq/callable-components` |
| logseq/rfx | Apache-2.0 | **no**, branch `logseq/fork` |
| logseq/cljs-time | not detected | yes |
| logseq/clj-fractional-indexing | EPL-1.0 | yes |
| logseq/logseq-schema | **none** | yes (only used in root deps.edn) |
| lambdaisland/glogi | MPL-2.0 | yes |
| metosin/malli | EPL-2.0 | yes |
| open-spaced-repetition/cljc-fsrs | MIT | yes |
| logseq/wally (clj-e2e tests only) | ? | **no**, branch `fork` |
| logseq/nbb-logseq (npm git dep for deps/* tests and scripts; branch `feat-db-v34`, commit 4d9f1382...) | MIT | yes |

- When forking these, copy all branches; `gh repo fork` copies all branches by default.
- Alternative the user was offered: **vendor** them into the fork (`deps/vendor/<name>` + `:local/root`), keeping each library's LICENSE file. Result: one self-contained repo. This has not been decided yet.
- Logseq npm packages (`mldoc` AGPL, `@logseq/react-tweet-embed`, `@logseq/simple-wave-record`) come from the npm registry, where published versions are immutable. Fork them only if they need fixes.
- iOS pods come from node_modules and Android deps from Maven/Google; there are no git deps there.

## Auth and external services (important)
- Sync requires a **Logseq account**. The app's sign-in is hardcoded to Logseq's AWS Cognito via aws-amplify:
  - `src/main/frontend/components/user/login.cljs`;
  - `deps/common/src/logseq/common/cognito_config.cljs` (client 69cs1lgme7p8kbgld8n5kseii6, OAuth domain logseq-prod.auth.us-east-1.amazoncognito.com);
  - `src/main/frontend/config.cljs` (pool us-east-1_dtagLnju8).
- Token refresh goes to `https://<oauth-domain>/oauth2/token` (`src/main/frontend/worker/sync/auth.cljs`).
- The server-side check is generic RS256 JWT (`deps/common/src/logseq/common/authorization.cljs`: iss, aud/client_id, exp, kid from JWKS), configured through `COGNITO_ISSUER`, `COGNITO_CLIENT_ID`, `COGNITO_JWKS_URL`. Replacing auth would mainly mean rewriting the client login.
- ADR `docs/adr/0001-nodejs-db-sync-server-adapter.md` (status Proposed) mentions pluggable auth providers as a goal; not implemented in 2.0.2.
- Never use `DB_SYNC_ALLOW_UNVERIFIED_JWT_CLAIMS` in production: it accepts forged tokens. It was used only for a local test.
- Other hosts the client calls:
  - api.logseq.io (default sync, replaced by the custom URL);
  - api.logseq.com (avatar upload, old file-sync);
  - logseq.io (publish; a custom URL setting exists);
  - plugins.logseq.io (plugin marketplace);
  - app.posthog.com (telemetry → turn off "usage diagnostics");
  - electron-updater publishing to GitHub logseq/logseq (`resources/electron-builder.yml` → turn off auto-update or change `publish`).

## Custom sync server URL (client)
- Stored in localStorage key `sync-server-url` (`src/main/frontend/config.cljs`).
- Where to set it in the UI:
  - desktop: Settings → Advanced → "Sync Server URL";
  - mobile: Settings → "Sync Server URL".
- Setting it also enables the sync (RTC) UI (`rtc-group?` in `src/main/frontend/handler/user.cljs`).
- The URL is converted to `wss://<host>/sync/<graph-id>`.

## macOS desktop build (not yet run; needs a Mac)
- Toolchain (per `.github/workflows/build.yml`): Node 24, pnpm 10.33.0, Java 21, Clojure CLI 1.12.4.x.
- Commands:
  - `pnpm install && pnpm release-electron:unsigned`.
  - The unsigned script `scripts/electron-builder-unsigned.mjs` disables signing and hardened runtime.
  - The build installs `static/` dependencies itself.
- Output: **`static/dist/`** (dmg + zip, e.g. `Logseq-darwin-arm64-2.0.2.dmg`). `docs/develop-logseq.md` says `static/out/`, which is outdated.
- First launch: right-click → Open (the app is unsigned).
- The app ID `com.logseq.logseq` and the name "Logseq" are the same as the official app, so both use the same data folder. Change `appId`/`productName` if they should coexist.

## iOS / Android notes (later)
- iOS: Mac + Xcode + CocoaPods; `pnpm run-ios-release` (see `docs/develop-logseq-on-mobile.md`). Must change:
  - bundle IDs `com.logseq.logseq` (+ `.ShareViewController`, `.shortcuts`);
  - `DEVELOPMENT_TEAM K378MFWK59`;
  - entitlements: iCloud `iCloud.com.logseq.logseq`, app group `group.com.logseq.logseq` (also hardcoded in `ios/App/ShareViewController/ShareViewController.swift:19`), `applinks:logseq.com`, push.
- A free Apple ID gives 7-day signing and no iCloud/push/associated domains; the paid Apple Developer Program (99 $/year) gives 1-year signing.
- Android: `applicationId com.logseq.app` (same as official → change it to install alongside the official app); `pnpm run-android-release`, then Build APK.

## Sync server (Docker) — tested
- Source: `deps/db-sync` (Node adapter, target `db-sync-node` → `worker/dist/node-adapter.js`).
- Storage: SQLite + filesystem.
- Endpoints: `/health`, `/graphs`, `/sync/<id>` (WebSocket), `/assets/`, `/e2ee`.
- Listens on all interfaces; `DB_SYNC_PORT`; data in `DB_SYNC_DATA_DIR`.
- What was tested in the sandbox:
  - the image builds (shadow-cljs, 0 warnings, ~480 MB);
  - a rebuild with no changes is fully cached;
  - through Caddy: HTTPS works, HTTP→HTTPS redirect, `/health` OK, 401 without login;
  - a full WebSocket session through Caddy works;
  - files in `./data` are owned by PUID:PGID and the process runs as uid 1000.
- Not tested: a real app login against it; a Let's Encrypt certificate.
- Data layout: `./data/index.sqlite`, `./data/graphs/<id>/db.sqlite`, `./data/assets/`. Back up `./data`.
- Deploy:
  1. `cp .env.example .env`;
  2. set `DOMAIN`, `LOGSEQ_REPO` (fork URL ending in `.git`), `LOGSEQ_REF` (e.g. `personal`), `PUID`/`PGID`;
  3. run `docker compose up -d --build`.
- The Clojure compile needs a decent amount of RAM; a 1 GB VPS may fail.

### Files (folder `logseq-sync/`)

#### Dockerfile
```dockerfile
# syntax=docker/dockerfile:1

# Self-hosted Logseq DB sync server (Node.js adapter from deps/db-sync).
# Built from a git repository and ref (branch, tag or commit). Use the same
# repository and ref as the Logseq apps on your devices.
ARG LOGSEQ_REPO=https://github.com/logseq/logseq.git
ARG LOGSEQ_REF=2.0.2
ARG NODE_IMAGE=node:24-bookworm-slim
ARG CLOJURE_IMAGE=clojure:temurin-21-tools-deps-bookworm

# ---------------------------------------------------------------------------
# Node.js runtime, reused by the build stage and the final image
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS node

# ---------------------------------------------------------------------------
# Build: Java 21 + Clojure CLI (from the base image) + Node.js + pnpm
# ---------------------------------------------------------------------------
FROM ${CLOJURE_IMAGE} AS build
ARG LOGSEQ_REPO
ARG LOGSEQ_REF
ARG PNPM_VERSION=10.33.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/include/node /usr/local/include/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && npm install -g "pnpm@${PNPM_VERSION}"

# Sources at the given ref. The ref is resolved to a commit on every build,
# so new commits on a branch are picked up without --no-cache.
ADD ${LOGSEQ_REPO}#${LOGSEQ_REF} /src

WORKDIR /src/deps/db-sync

# npm packages (production only: wrangler and other dev tools are not needed)
RUN pnpm install --prod --frozen-lockfile --ignore-workspace

# Clojure dependencies, then the release build of the Node adapter
RUN clojure -P -M:cljs
RUN clojure -M:cljs release db-sync-node \
 && test -s worker/dist/node-adapter.js

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM node AS runtime
ARG LOGSEQ_REPO
ARG LOGSEQ_REF

LABEL org.opencontainers.image.title="logseq-sync" \
      org.opencontainers.image.description="Self-hosted Logseq DB sync server" \
      org.opencontainers.image.source="${LOGSEQ_REPO}" \
      org.opencontainers.image.version="${LOGSEQ_REF}"

# Authentication uses the official Logseq accounts (the same values the
# Logseq app uses). Graph data is stored only on this server.
ENV NODE_ENV=production \
    DB_SYNC_PORT=8787 \
    DB_SYNC_DATA_DIR=/data \
    COGNITO_ISSUER=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_dtagLnju8 \
    COGNITO_CLIENT_ID=69cs1lgme7p8kbgld8n5kseii6 \
    COGNITO_JWKS_URL=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_dtagLnju8/.well-known/jwks.json \
    PUID=1000 \
    PGID=1000

WORKDIR /app
COPY --from=build /src/deps/db-sync/node_modules ./node_modules
COPY --from=build /src/deps/db-sync/worker/dist/node-adapter.js ./worker/dist/node-adapter.js

# Starts as root only to prepare the data folder, then drops to PUID:PGID,
# so files in the bind-mounted folder belong to your user on the host.
COPY --chmod=755 <<'EOF' /usr/local/bin/logseq-sync-entrypoint
#!/bin/sh
set -eu
mkdir -p "$DB_SYNC_DATA_DIR"
if [ "$(id -u)" = "0" ]; then
  if [ "$(stat -c %u:%g "$DB_SYNC_DATA_DIR")" != "$PUID:$PGID" ]; then
    chown -R "$PUID:$PGID" "$DB_SYNC_DATA_DIR"
  fi
  exec setpriv --reuid="$PUID" --regid="$PGID" --clear-groups "$@"
fi
exec "$@"
EOF

EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.DB_SYNC_PORT+'/health').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"

ENTRYPOINT ["logseq-sync-entrypoint"]
CMD ["node", "/app/worker/dist/node-adapter.js"]
```

#### docker-compose.yml
```yaml
services:
  logseq-sync:
    build:
      context: .
      args:
        LOGSEQ_REPO: ${LOGSEQ_REPO:-https://github.com/logseq/logseq.git}
        LOGSEQ_REF: ${LOGSEQ_REF:-2.0.2}
    image: logseq-sync:local
    container_name: logseq-sync
    restart: unless-stopped
    environment:
      DB_SYNC_BASE_URL: https://${DOMAIN:?set DOMAIN in .env}
      PUID: ${PUID:-1000}
      PGID: ${PGID:-1000}
    volumes:
      # Graphs (SQLite) and assets are stored next to this file, in ./data
      - ./data:/data
    # Not published to the host: only reachable through Caddy
    expose:
      - "8787"

  caddy:
    image: caddy:2
    container_name: logseq-sync-caddy
    restart: unless-stopped
    depends_on:
      logseq-sync:
        condition: service_healthy
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    environment:
      DOMAIN: ${DOMAIN:?set DOMAIN in .env}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      # TLS certificates and Caddy state
      - ./caddy/data:/data
      - ./caddy/config:/config
```

#### Caddyfile
```
{$DOMAIN} {
	# HTTPS certificates are issued automatically (Let's Encrypt).
	# WebSocket connections (/sync/...) are proxied without extra settings.
	reverse_proxy logseq-sync:8787
}
```

#### .env.example
```bash
# Domain that points to this server (A/AAAA record). Caddy gets the
# HTTPS certificate for it automatically; ports 80 and 443 must be open.
DOMAIN=sync.example.com

# Where the sync server is built from: your fork (URL must end with .git)
# and your branch, a tag or a commit. Use the same code as your Logseq apps.
LOGSEQ_REPO=https://github.com/logseq/logseq.git
LOGSEQ_REF=2.0.2

# Owner of the files in ./data (run `id -u` and `id -g` on the host).
PUID=1000
PGID=1000
```

#### .dockerignore
```
# The image is built from the Logseq sources on GitHub; nothing from this
# folder is needed (and ./data with your graphs must not be sent to the build).
*
```
