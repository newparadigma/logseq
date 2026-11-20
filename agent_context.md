# Agent context: personal Logseq fork

## Goal
- Personal, long-lived fork of Logseq **2.0.2** (DB version). Own development line; no plans to follow upstream updates.
- Personal use only: fix bugs and add features.
- Targets, in order: **macOS desktop app + self-hosted sync server** first; iOS and Android later.

## Status (as of 2026-11-20)
- Done (2026-11-20): sync without a Logseq account, using self-issued tokens. See "Self-hosted token sign-in" below. Tested end to end as a web app with two devices against a local sync server; LogseqDEV rebuilt and launch-tested (see the 2026-11-20 build section).
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
- Official sync requires a **Logseq account**; the self-hosted server no longer does (see "Self-hosted token sign-in"). The app's Cognito sign-in is hardcoded to Logseq's AWS Cognito via aws-amplify:
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

## Self-hosted token sign-in (2026-11-20)
- Goal: sync with the self-hosted server without a Logseq/Cognito account. The server code is unchanged: its RS256 JWT check accepts any issuer configured through `COGNITO_ISSUER`, `COGNITO_CLIENT_ID`, `COGNITO_JWKS_URL`.
- `deps/db-sync/scripts/selfhost-token.mjs` (Node, built-in `crypto` only):
  - `init <dir> --issuer <url> --username <name> [--email <e>]`: creates `<dir>/private.pem` and `<dir>/settings.json` (issuer, kid, sub), mode 0600, and prints the three `COGNITO_*` lines for the server `.env`. Refuses to overwrite an existing key.
  - `env <dir>`: prints those lines again. `token <dir> [--days N]` (default 3650): prints a signed JWT.
  - `COGNITO_CLIENT_ID=logseq-selfhost`. `COGNITO_JWKS_URL` is a `data:application/json,...` URL; the server's Node `fetch` reads it, so no extra host serves the keys.
  - `sub` is the server user id, fixed in `settings.json`. All tokens for all devices share it, so several devices use the same graphs. Tokens carry `cognito:username` and optional `email`/`email_verified`.
  - Keep `<dir>` private: whoever has `private.pem` can sign in as you. To revoke tokens, run `init` in a new dir and redeploy the `.env`; the server keeps accepting a cached token for up to 1 hour.
- Client:
  - `frontend.handler.user/login-with-self-hosted-token!` checks that the token parses and has `sub` and a future `exp`. It then stores the token as the id, access and refresh token, so `logged-in?` and the restore after restart work unchanged. When the token is within 1 hour of `exp`, the Cognito refresh is expected to fail with `invalid_grant` (not tested) and log the user out: they must paste a new token.
  - Settings, the Sync Server URL dialog (desktop and mobile): after a URL is saved, an "Access token" field and a "Sign in with token" button appear (`self-hosted-token-form` in `src/main/frontend/components/settings.cljs`).
  - `:user/fetch-info-and-graphs` (`src/main/frontend/handler/events/ui.cljs`) does not call the Logseq `user_info` API when a custom sync server URL is set; it uses `{}`. Without this, the graph list and sync never started. A Cognito user with a custom server therefore also gets no Logseq user groups/plan info.
  - i18n keys `:settings.sync-server/token-*` were added in en, zh-cn and ru.
  - Logout clears all localStorage, including the sync server URL; set it again after logout.
- Verification:
  - In Docker (`node:24-bookworm-slim`, the compiled `worker/dist/node-adapter.js` built on 2026-11-18; the auth code is unchanged since October): `/graphs` returns 401 without a token, 200 with a self-issued token, and 401 for a changed signature byte, a token from another key, and a token that reuses the real `kid` with a foreign key. Graph creation returns `missing user rsa key pair` until the client uploads its E2EE keys (expected).
  - Negative-test lesson: changing the last base64url character of a 2048-bit RS256 signature may not change the signature (that character carries only 2 bits). The first test passed for this reason; change a middle character instead.
  - i18n lint (hardcoded text, keys), `bb lang:validate-translations`, and `bb lang:format-dicts` pass. clj-kondo on the 3 changed CLJS files: 0 errors, 1 pre-existing warning (`<wrap-ensure-id&access-token` macro).
  - `bb lang:format-dicts` failed on a tarball made by macOS `tar`; on a read-only mount copy it passed. Use a mount copy or `git archive` for container checks.
  - CLJS release build (2026-11-20, Docker `logseq-macos-builder:local`, volume `logseq-build-20261120`): all 5 targets compiled; no warnings in the changed files.
  - Web app end-to-end test (2026-11-20): the release web build in `static/` served by `http-server` on port 18080; the sync server from the compiled node adapter in Docker on `http://127.0.0.1:18787` with self-issued token settings. Two browser origins (`localhost:18080`, `127.0.0.1:18080`) acted as two devices with separate storage and two different tokens for the same `sub`.
    - An invalid token shows "The access token is invalid or expired."; a valid token signs in, `/graphs` is called on the local server, and no request goes to `logseq.com` or Cognito.
    - Device A: E2EE password set, RSA keys uploaded, an encrypted synced graph created, presence avatar shown. Device B: the remote graph listed, downloaded after the E2EE password, and showed A's text. B's edit appeared on A. After a reload, A stayed signed in and synced.
    - Pre-existing UX issue: the "Set password for remote graphs" dialog can open hidden under the "Create a new graph" dialog, which keeps Submit disabled; Escape cancels the password request. The Settings "Sync Server URL" button label does not refresh until Settings is reopened.
  - Not done: a real Electron GUI run, mobile, HTTPS/Caddy deployment, and token expiry/logout behavior.

## Custom sync server URL (client)
- Stored in localStorage key `sync-server-url` (`src/main/frontend/config.cljs`).
- Where to set it in the UI:
  - desktop: Settings → Advanced → "Sync Server URL";
  - mobile: Settings → "Sync Server URL".
- Setting it also enables the sync (RTC) UI (`rtc-group?` in `src/main/frontend/handler/user.cljs`).
- The URL is converted to `wss://<host>/sync/<graph-id>`.

## macOS desktop build — LogseqDEV ARM64 (2026-11-18)
- Superseded artifact: see the 2026-11-20 rebuild below. The packaging notes here still apply.
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

## macOS desktop build — rebuild with token sign-in (2026-11-20)
- Current artifact: `static/dist/LogseqDEV-darwin-arm64-2.0.2.zip`, 181,918,528 bytes, SHA-256 `8fff6dcc0ff00dd142377d82e418d6d1d1755be7c8b7d7220d4d07ada7808cbd` (`SHA256SUMS`, `verification.json` updated): the token build below plus the orange icon. The 2026-11-18 artifact and the first 2026-11-20 artifact (`6050fc8c...`) are gone.
- Built from the working tree with the self-hosted token changes (uncommitted at build time).
- Verified on the host: `codesign --verify --deep --strict` passes, arm64 Mach-O, bundle ID `com.logseq.logseqdev`, the `:settings.sync-server/token-*` keys are in `app.asar` `js/main.js`. A launch with `--user-data-dir` in a temp folder and `--remote-debugging-port` loaded the renderer page `Logseq`; no errors in the log. Sign-in was not clicked through in Electron: the same release renderer code was tested as a web app (see "Self-hosted token sign-in").
- Scripts and logs: `.tmp/macos-build-20261120/` (gitignored). Run them in this order:
  1. On the host, `git ls-files -co --exclude-standard -z > <dir>/files.lst`.
  2. `run-a.sh <repo> <dir>`: copies the listed files into Docker volume `logseq-build-20261120`, then pnpm install, `gulp:build`, `cljs:release-electron`, `webpack-app-build`.
  3. `run-b.sh x <dir>`: opam switch 5.3.0 in `/work/opam` on the volume (kept, about 5 GB in the volume in total), CLI deps, `db-worker-node:bundle`, `cli:release`, `desktop:prepare-runtime-js`, version, then the isolated Darwin package tree, keytar prebuild, electron-builder zip, rcodesign 0.29.0 (checksum-verified) ad-hoc signing, re-zip to `<dir>/out`.
  4. `run-c.sh x <dir>`: only the packaging part of `build-b.sh`.
  Each run script removes its named container on exit or interrupt.
- User rule (2026-11-20): after every macOS build, install it into `/Applications/LogseqDEV.app` right away. Procedure: check the app is not running; extract the zip with `ditto -x -k` into a temp folder in `/Applications`; verify `codesign --verify --deep --strict`; move the old app to `~/.Trash`; move the new app into place. The 2026-11-18 app is in `~/.Trash/LogseqDEV-20261118.app`.
- Orange icon (2026-11-20, user request, so LogseqDEV is not confused with the official app): `resources/icons/logseq_big_sur.icns` (macOS app icon), `logseq_big_sur.png`, `logseq.icns`, `logseq.png` (window icon) recolored: dark teal background becomes orange `#EA6216`, light teal blobs become cream `#FFE4C4`; transparent and grey shadow pixels are kept, anti-aliased pixels are interpolated. Script: `.tmp/icon-recolor-20261120/recolor.py` (Pillow 11.3.0 in a `python:3.12-slim` container); `.icns` files were rebuilt with macOS `iconutil`. Not recolored: Windows `.ico` files, `resources/icons/canary/`, `resources/icon.png`, `icon_monochrome.png`, and the in-app logo. Only the packaging stage (`run-c.sh`) was rerun after copying the icons into `resources/icons` and `static/icons` in the build volume. The installed app's `Contents/Resources/icon.icns` matches the orange file.
- Installed now: `/Applications/LogseqDEV.app` is the orange build; the teal 2026-11-20 build is in `~/.Trash/LogseqDEV-20261120-teal.app`.
- Fix found in this build: the isolated package tree also needs `deps/graph-lifecycle`, because `resources/package.json` uses `file:../deps/graph-lifecycle`; without it pnpm fails with `ENOENT ... scandir '/work/package/deps/graph-lifecycle'`.
- `@zvec/zvec` postinstall in the Darwin tree logs a failed linux-arm64 prebuilt download; harmless, the app bundles `@zvec/bindings-darwin-arm64`.
- Electron writes tokens to `~/logseq/auth.json` (`persist-auth-file!`, existing behavior for Cognito tokens too), so a self-issued token is also stored there in plain text.

## Missing graph folder on open (fixed 2026-11-20)
- Problem: a graph deleted outside the app (folder removed from `~/logseq/graphs`) stays in the graph list until the list refreshes. Opening it hung: `:graph/switch` → `restore-and-setup-repo!` sets `db-restoring` to true, the main-process IPC `db-worker-runtime` fails in `graph-lifecycle` `requireAvailable` with `Graph is absent or stopped by deletion`, and the restoring flag is never cleared. The normal "Delete local graph" path also fails for such a graph (`lifecycle/deleteGraph` reports `existed: false`, then `<unlink-graph!` throws `Graph does not exist`).
- Fix: `:graph/switch` (`src/main/frontend/handler/events.cljs`) first calls `repo-handler/<graph-dir-missing?` (Electron only, the Demo graph excluded): the graph is missing when the main-process `getGraphs` list (folders in the graphs dir) does not contain it. Then it shows a confirm dialog (`:graph/missing-confirm-desc`, button `:graph/remove-missing-action`); OK calls `repo-handler/remove-missing-repo!`, which only removes the entry from the in-memory list (`state/delete-repo!`) and shows `:graph/removed`. Nothing on disk is touched; the stale `.graph-lifecycle/<...>/<graph>/` folder stays.
- Startup path (added the same day): if the remembered current graph has no folder, `persist-db/<start-runtime!` failed, the whole startup chain in `src/main/frontend/handler.cljs` aborted with `Error while restoring repos: ... Graph is absent or stopped by deletion`, and the graph list stayed empty. This is the most likely cause of the reported first-run empty list. Now `repo-handler/<forget-missing-current-repo!` runs before `<start-runtime!`: it clears the current graph and shows the warning `:graph/missing-startup-warning`. After `resolve-startup-repo`, a chosen graph without a folder (from a tab or URL target) falls back to the first listed graph. `resolve-startup-repo` itself is unchanged (its tests expect URL/tab targets outside the list).
- Verified 2026-11-20 13:25 in the installed build (SHA-256 `9cfefaf7...` in `static/dist`): with the remembered graph `gmbnaallahglobal` absent from `~/logseq-dev`, LogseqDEV started without `Graph is absent` errors and opened `pharmakey` from `~/logseq-dev/graphs` with its content; the graph list loaded. The user confirmed seeing the warning and dialog messages. The test folder `~/logseq-dev/graphs/zz-missing-test` was created for the dialog test and removed.
- Not covered: web/mobile.
- Checks: clj-kondo 0 warnings on the 2 changed files; i18n lint, `bb lang:validate-translations`, `bb lang:format-dicts --check` pass. i18n keys added in en, zh-cn, ru.

## Separate data root for LogseqDEV: ~/logseq-dev (2026-11-20)
- Why: the official Logseq app and LogseqDEV shared `~/logseq` and fought over the same graph's worker (see Known issues). User decision: LogseqDEV uses its own root `~/logseq-dev`.
- Code: `deps/common/src/logseq/common/config.cljs` `default-graphs-dir` = `~/logseq-dev/graphs`; `src/main/logseq/cli/root_dir.cljs` `default-root-dir` = `~/logseq-dev` (used by Electron for workers, `.graph-lifecycle`, `server-list`); `src/main/frontend/config.cljs` graphs-dir fallback; `auth.json` paths in `src/main/frontend/handler/user.cljs` and `src/main/frontend/worker/sync/crypt.cljs` (+ 2 assertions in `src/test/frontend/worker/sync/crypt_test.cljs`). `LOGSEQ_GRAPHS_DIR` still overrides the graphs dir.
- Not changed: `~/.logseq` (global config, plugins) is still shared with the official app; the cli-e2e sync fixtures still copy `~/logseq/auth.json` (explicit paths, official-account tests); LogseqDEV still installs its CLI launcher at `~/.local/bin/logseq`, the same path the official app uses, and that CLI now defaults to `~/logseq-dev`.
- Data move (user request, both apps quit, no Logseq processes running): `~/logseq/graphs/pharmakey` → `~/logseq-dev/graphs/pharmakey` (13 MB, `mv`; `pragma integrity_check` ok on a copy afterwards). `gmbnaallahglobal` and `main` stay in `~/logseq/graphs` for the official app. The official app keeps a stale `~/logseq/.graph-lifecycle/.../pharmakey/` entry.
- clj-kondo on the changed files: 0 errors, 1 pre-existing warning.

## Known issues (not fixed)
- First LogseqDEV launch crash (reported 2026-11-20, user said not to fix now): on the very first run the graph list (top left) was empty; the user chose to point to an existing graph folder (`~/logseq/graphs/gmbnaallahglobal`), and the app showed the "Something went wrong" error screen. The error text was not captured (renderer errors are not written to log files; DevTools or `--remote-debugging-port` is needed). After a restart the same graph opens normally. Related observations from the same day:
  - The official Logseq app and LogseqDEV share `~/logseq` (graphs, `.graph-lifecycle`, `server-list`, `auth.json`) and `~/.logseq`; both were running at the same time.
  - After LogseqDEV quits, its `db-worker-node` process for the open graph keeps running detached for several minutes; when it exits, a running LogseqDEV logs `:db-worker-event-stream-error` and `:db-worker-runtime-recovering` and starts a new worker (it recovered without a crash).
  - LogseqDEV's localStorage still lists `pharmackey backend`, a graph whose folder no longer exists; every start logs `Graph is absent or stopped by deletion` for it.
- Likely root cause of the empty graph list / first-run crash (found 2026-11-20 12:20): when the official Logseq app and LogseqDEV run at the same time and open the same graph, each app sees the other's `db-worker-node` for that graph with a different build revision (official `533ac43`, LogseqDEV `dev`, because the Docker build has no Git metadata). LogseqDEV logs `:cli-server-restart-version-mismatch` and replaces the worker; the official app does the same, and the race ends in `Error: Worker admission registration changed` (`deps/graph-lifecycle/index.cjs:255`, IPC `db-worker-runtime`). In the renderer this surfaces as `Error while restoring repos: ... Worker admission registration changed` (`src/main/frontend/handler.cljs:200`), and the graph list (switcher and All graphs) stays empty. Possible fixes, not chosen yet: a separate root dir for LogseqDEV (for example `~/logseq-dev`), or never running both apps on the same graph.
- How to capture renderer errors: quit LogseqDEV (`osascript -e 'quit app "LogseqDEV"'`), start it with `open -a /Applications/LogseqDEV.app --args --remote-debugging-port=19333`, and subscribe to `Runtime.exceptionThrown` / `Runtime.consoleAPICalled` over CDP (a small Node script using the global `WebSocket` is enough).

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
- The compose file and `.env.example` below now require the self-issued token settings (`COGNITO_*`); the Dockerfile defaults to the official Logseq accounts and compose overrides them. These files exist only in this document, not in the repository.
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
      # Self-issued sign-in tokens (deps/db-sync/scripts/selfhost-token.mjs)
      COGNITO_ISSUER: ${COGNITO_ISSUER:?set COGNITO_ISSUER in .env}
      COGNITO_CLIENT_ID: ${COGNITO_CLIENT_ID:?set COGNITO_CLIENT_ID in .env}
      COGNITO_JWKS_URL: ${COGNITO_JWKS_URL:?set COGNITO_JWKS_URL in .env}
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

# Sign-in without a Logseq account. Paste the 3 lines printed by:
#   node deps/db-sync/scripts/selfhost-token.mjs init ~/logseq-sync-auth --issuer https://sync.example.com/ --username me
# Then issue a token for the apps with:
#   node deps/db-sync/scripts/selfhost-token.mjs token ~/logseq-sync-auth
COGNITO_ISSUER=
COGNITO_CLIENT_ID=
COGNITO_JWKS_URL=
```

#### .dockerignore
```
# The image is built from the Logseq sources on GitHub; nothing from this
# folder is needed (and ./data with your graphs must not be sent to the build).
*
```
