# Agent context: personal Logseq fork

## Goal
- Personal, long-lived fork of Logseq **2.0.2** (DB version). Own development line; no plans to follow upstream updates.
- Personal use only: fix bugs and add features.
- Targets, in order: **macOS desktop app + self-hosted sync server** first; iOS and Android later.

## Status (as of 2026-11-18)
- Done: a Docker setup for the sync server (Dockerfile, docker-compose.yml with Caddy). It was built and smoke-tested in a Linux sandbox (see "Sync server" below).
- Done: the GitHub fork of `logseq/logseq` (reported by the user).
- Done: vendored 21 Git repositories into `deps/vendor/`, including development/test tooling, transitive Git dependencies, the OCaml CLI libraries, and iOS Drops. See "Vendored dependencies" below.
- Done: the first macOS ARM64 build, named `LogseqDEV`, compiled, packaged, and ad-hoc signed inside Docker. Artifact and verification details are below.
- Not done yet: confirmation of the personal branch, full desktop UI/sync testing, and deployment against the personal sync server.
- Suggested next steps:
  1. Confirm the fork URL, personal branch, and intended base revision.
  2. Install/test the built LogseqDEV app. Keep future npm/opam/toolchain installations inside Docker.
  3. Point the server's `.env` at the fork and the personal branch.

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
- Decision: vendor Git dependencies into this repository (`deps/vendor/<name>` + `:local/root`) instead of maintaining separate forks. Implemented on 2026-11-18; npm/Maven packages remain external.
- Logseq npm packages (`mldoc` AGPL, `@logseq/react-tweet-embed`, `@logseq/simple-wave-record`) come from the npm registry, where published versions are immutable. Fork them only if they need fixes.
- Correction: iOS also had a direct Git dependency on `omaralbeik/Drops` at tag `1.7.0`. It is now vendored and referenced through a local Podfile path. Other iOS pods come from node_modules/registries; Android dependencies use Maven/Google.

## Vendored dependencies (2026-11-18)
- Source checkout: `8bcad1f273f9ebced4d5bf161ccbee29ff136ff3`; no dependency version upgrade was performed. This checkout has not been verified as tag `2.0.2`.
- `deps/vendor/manifest.json` records the original repositories, pinned refs, full commit SHAs, archive SHA-256 values, and retained paths. `deps/vendor/README.md` explains scope and maintenance.
- Initial 17 snapshots: datascript, hsx, rfx, cljs-time, clj-fractional-indexing, logseq-schema, glogi, malli, cljc-fsrs, bb-tasks, carve, clj-kondo-bb, nbb-logseq, nbb-test-runner, test-runner, wally, Drops.
- Follow-up: the initial scan missed `cli/logseq-cli.opam` and `cli/logseq-cli.opam.template`. Four additional repositories are now vendored: melange-edn, melange-transit, humanize, rrbvec (21 repositories total, providing six additional opam packages). Their original refs floated on `main`; the current commits were resolved and recorded in the vendor manifest rather than silently retaining moving branches.
- Both CLI opam files now use local `pin-depends` paths. Run opam dependency setup from `cli/`, matching the existing CI workflows, because opam interprets relative URLs against its working directory. Docker images must copy both the CLI and vendor trees with their relative layout intact.
- OCaml snapshots preserve all 122 upstream files byte for byte, including Dune build definitions, opam manifests, tests, and available licenses. The CLI's Dune files are unchanged. No transitive Git pins were found in those four repositories. Upstream `dev-repo` metadata remains informational.
- Container-only validation passed: opam 2.3.0 registered all six packages from local paths with Docker networking disabled, both before and after relocating the project. Direct pinning of an intentionally missing rrbvec tree failed and identified that exact path. The generated CLI opam file's pin section matches its template; existing package metadata/constraints are unchanged.
- A second disposable Docker container successfully ran `opam install . --deps-only --yes` from the copied CLI directory. All six local packages built and installed: melange-edn-core/melange-edn-melange 0.5.0, melange-transit-core/melange-transit-melange 0.1.2, humanize.dev, rrbvec.dev. Other dependencies came from the opam registry. Validation used Debian 13, OCaml 5.3.0, Dune 3.24.2, and Melange 7.0.1-53; the repository workflow's OCaml 5.1.1 target and full desktop packaging were not tested in this follow-up.
- Known opam behavior: `--yes` may continue after an extra pin's source cannot be retrieved. Container setup should preflight the four local source directories; the vendor README includes that check.
- User decision: future package/toolchain installation and builds belong in Docker containers, with no further npm/opam/toolchain installations on the host. The Docker daemon is available. Validation containers use read-only project mounts and copy sources internally; no host node_modules or opam switch is created by this follow-up.
- The earlier dependency table omitted bb-tasks, nbb-test-runner, test-runner, Drops, and transitive carve/clj-kondo-bb. Treat the vendor manifest as the source of truth for the current checkout.
- Clojure, Babashka, and nbb manifests use local paths, including transitive Git dependencies. Upstream development aliases/examples/tests are omitted from the library snapshots; runtime source and resources are retained unchanged.
- nbb-logseq uses its existing compiled JavaScript and local pnpm `file:` dependencies in six consumers. Its `import-meta-resolve` constraint is pinned to the existing locked version `4.1.0`; the six lockfiles retain all other package versions.
- Drops keeps its original podspec, Swift sources, and license. Podfile/Podfile.lock use a local path; the Podfile checksum is updated.
- Third-party snapshots are excluded from project translation and spelling checks.
- Validation passed: application, server, and app E2E Maven dependency resolution; all six affected npm frozen-lockfile installs; common-library suite (27 tests, 153 assertions, no failures); semantic comparison of 44 EDN manifests and 76 local paths; 216 copied files match their pinned archives byte for byte and all vendor files are visible to git. All six lockfiles preserve registry package versions and dependency snapshots. TOML/Ruby/YAML syntax and local Drops configuration checks pass.
- The sync-server release build completed (266 files, 161 compiled). It reported 24 type-inference warnings in unchanged vendored datascript/cljs-time sources. Full macOS/iOS packaging and browser E2E execution have not been run.
- Tooling: `spec-dev-tool` was not installed. Clojure CLI 1.12.4.1618, Babashka 1.12.215, and pnpm 10.33.0 were downloaded to `/tmp/logseq-vendor-downloads/` for validation. The available Node version was 26.8.1; the server release compiler used installed JDK 25. The normal target toolchain remains Node 24 / Java 21. Installed node_modules and ignored build caches remain local.
- npm/Maven packages, toolchains, and runtime binaries still use external sources; this change does not provide a fully offline build or replace account authentication.

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

## macOS desktop build — LogseqDEV ARM64 (2026-11-18)
- Completed: compilation, macOS packaging, and ad-hoc signing inside Linux Docker. No host package installation was performed. Native macOS tools were used only to extract and verify the result; the app binary was exercised in Node mode without opening the GUI or user graphs.
- User-requested application name: `LogseqDEV`. Desktop package name/productName are `LogseqDEV`; bundle ID is `com.logseq.logseqdev`. This also gives Electron a separate default userData profile (`~/Library/Application Support/LogseqDEV`). Shared graph paths and `~/.logseq` behavior have not been changed.
- Artifact: `static/dist/LogseqDEV-darwin-arm64-2.0.2.zip`, 182,110,482 bytes; SHA-256 `9782e92edf5c3be38fd4f8f1a9a3efe3ddc40921e198ace1e1bc4cf6966e5361`. `static/dist/verification.json` and `SHA256SUMS` accompany it. It is ad-hoc signed, without an Apple Developer certificate or notarization. No DMG was produced.
- Source snapshot: Git checkout `9e3eeb9a00` plus the requested desktop name/ID changes, captured as `/tmp/logseq-macos-build-20261118/source.tar` (tracked working files, without `.git` or host node_modules). Embedded revision metadata is `dev` because Git metadata was excluded. Docker build image: `logseq-macos-builder:local`.
- Temporary orchestration lives under `/tmp/logseq-macos-build-20261118/`; logs are in `.tmp/macos-build-20261118/` (`image.log`, `build.log`, `package.log`, `sign.log`, `runtime-smoke.log`). Docker launch wrappers remove their container on success, error, and interrupt; interruption cleanup was exercised during the name change. All build containers, the temporary `logseq-macos-build-work-20261118` volume, and the extracted host verification copy were removed after successful verification. Docker build images remain cached; a new build must recreate its work volume.
- Toolchain: Node 24, pnpm 10.33.0, Java 21, Clojure CLI 1.12.4.1618, OCaml 5.3.0/Dune 3.24.2/Melange 7.0.1-53. Frozen npm installs were preserved. All five CLJS release targets completed (app, db-worker, db-worker-node, electron, publishing; 107 compiler warnings total), followed by worker bundling, webpack, and the OCaml CLI bundle.
- Packaging correction: invoking electron-builder from `static/` under the root workspace caused its dependency collector to fall back to the Linux frontend dependency tree. CLI dotted `supportedArchitectures` settings did not install the Darwin binding. The final desktop tree was isolated under `/work/package/static` in Docker with its own `pnpm-workspace.yaml` containing `supportedArchitectures: {os: [darwin], cpu: [arm64]}`. It was installed independently with the same frozen resources lockfile. keytar's macOS ARM64 N-API prebuild was installed explicitly; rebuild was disabled only after verifying the prebuilt architecture. Linux/Windows native modules were excluded from the app.
- electron-builder 26.17.0 packaged the macOS ZIP on Linux but skipped signing, leaving an invalid original Electron resource seal after renaming. rcodesign 0.29.0 (checksum-verified Linux ARM64 release) recursively ad-hoc signed the app and native modules **inside Docker**; Linux `zip -r -y` then recreated the final archive with symlinks preserved.
- Verification passed: ZIP integrity; CFBundleName/CFBundleExecutable `LogseqDEV`; CFBundleIdentifier `com.logseq.logseqdev`; executable mode; ARM64 Mach-O executable and both `.node` modules; sidecar presence; native macOS `codesign --verify --deep --strict`; real Darwin ARM64 binary execution with Electron 42.11.16 / Node 24.19.0, loading keytar and zvec successfully. Full GUI, graphs, sync, updater, and notarization were not tested.
- Toolchain (per `.github/workflows/build.yml`): Node 24, pnpm 10.33.0, Java 21, Clojure CLI 1.12.4.x.
- Commands:
  - `pnpm install && pnpm release-electron:unsigned`.
  - The unsigned script `scripts/electron-builder-unsigned.mjs` disables signing and hardened runtime.
  - The build installs `static/` dependencies itself.
- Output: **`static/dist/`** (dmg + zip, e.g. `Logseq-darwin-arm64-2.0.2.dmg`). `docs/develop-logseq.md` says `static/out/`, which is outdated.
- For the delivered app, use the LogseqDEV artifact and identity above; the simple release command does not include the Docker cross-packaging/ad-hoc signing corrections described here.

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
