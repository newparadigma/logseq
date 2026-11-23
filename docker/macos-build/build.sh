#!/bin/bash
# Runs inside the builder container. The project is mounted read-write at
# /work/src; the cache volume is mounted at /work (opam switch, Maven/pnpm/
# Electron caches, the Darwin packaging tree). Writes the signed app (no zip) to
# /work/src/.tmp/macos-build/LogseqDEV.app.
set -euo pipefail

SRC=/work/src
CACHE=/work/cache
PKG=/work/package
OUT=$SRC/.tmp/macos-build
RCODESIGN_URL=https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign/0.29.0/apple-codesign-0.29.0-aarch64-unknown-linux-musl.tar.gz

step_start=$(date +%s)
step() {
  local now; now=$(date +%s)
  echo "== $* (previous step: $((now - step_start))s)"
  step_start=$now
}

# Persistent caches: tools write under $HOME, so point those folders at the volume.
mkdir -p "$CACHE"/{m2,gitlibs,xdg,npm,pnpm-store,rcodesign} "$OUT"
for pair in .m2:m2 .gitlibs:gitlibs .cache:xdg .npm:npm; do
  rm -rf "/root/${pair%%:*}"
  ln -s "$CACHE/${pair##*:}" "/root/${pair%%:*}"
done
export npm_config_store_dir=$CACHE/pnpm-store
git config --global --add safe.directory "$SRC"

cd "$SRC"
step "pnpm install"
pnpm install --frozen-lockfile

# Hash of every tracked or new file that feeds the web/Electron bundles. When it
# matches the last good build and the bundles exist, gulp/CLJS/webpack are skipped.
app_stamp=$(git ls-files -co --exclude-standard -z -- . \
              ':!agent_context.md' ':!docs' ':!docker' ':!cli' ':!cli-e2e' ':!clj-e2e' ':!android' ':!ios' \
            | xargs -0 sh -c 'for f; do [ -f "$f" ] && printf "%s\0" "$f"; done' sh \
            | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
if [ "$(cat "$CACHE/app-bundle.sha" 2>/dev/null)" = "$app_stamp" ] && [ -s static/js/main.js ] && [ -s static/electron.js ]; then
  step "app sources unchanged: gulp, CLJS and webpack skipped"
else
  rm -f "$CACHE/app-bundle.sha"
  step "gulp build"
  pnpm gulp:build

  step "cljs release (incremental cache in .shadow-cljs)"
  pnpm cljs:release-electron

  step "webpack"
  pnpm webpack-app-build
  echo "$app_stamp" > "$CACHE/app-bundle.sha"
fi

step "opam"
[ -f "$OPAMROOT/config" ] || opam init --bare --disable-sandboxing -y
opam switch list --short 2>/dev/null | grep -qx default || opam switch create default ocaml-base-compiler.5.3.0
eval "$(opam env --switch=default --set-switch)"
for d in melange-edn melange-transit humanize rrbvec; do
  test -f "deps/vendor/$d/dune-project" || { echo "missing vendor $d"; exit 1; }
done
opam_stamp=$(cat cli/*.opam deps/vendor/manifest.json | sha256sum | cut -d' ' -f1)
if [ "$(cat "$CACHE/opam-deps.sha" 2>/dev/null)" != "$opam_stamp" ]; then
  (cd cli && opam install . --deps-only --yes)
  echo "$opam_stamp" > "$CACHE/opam-deps.sha"
else
  echo "opam deps unchanged, skipped"
fi

step "CLI and desktop bundles"
pnpm --dir cli install --frozen-lockfile --ignore-workspace
pnpm db-worker-node:bundle
pnpm cli:release
pnpm desktop:prepare-runtime-js
node -e '
const fs=require("fs");const p="static/package.json";const pkg=JSON.parse(fs.readFileSync(p));
pkg.version=fs.readFileSync("src/main/frontend/version.cljs","utf8").match(/[0-9.]{3,}/)[0];
fs.writeFileSync(p,JSON.stringify(pkg,null,2));console.log("version",pkg.version)'
rm -rf static/mobile static/android static/ios

step "Darwin package tree (kept between builds)"
mkdir -p "$PKG/static" "$PKG/deps"
rsync -a --delete --exclude node_modules --exclude dist --exclude pnpm-workspace.yaml static/ "$PKG/static/"
rsync -a --delete --exclude node_modules deps/graph-lifecycle "$PKG/deps/"
cd "$PKG/static"
printf 'supportedArchitectures:\n  os: [darwin]\n  cpu: [arm64]\n' > pnpm-workspace.yaml
pnpm install --frozen-lockfile
keytar=$(ls -d node_modules/.pnpm/keytar@*/node_modules/keytar)
if ! file "$keytar/build/Release/keytar.node" 2>/dev/null | grep -q "Mach-O 64-bit arm64"; then
  for attempt in 1 2 3; do
    (cd "$keytar" && npx -y prebuild-install@7.1.3 --platform darwin --arch arm64 -r napi) && break
    echo "keytar prebuild download failed (attempt $attempt)"
  done
fi
file "$keytar/build/Release/keytar.node" | grep -q "Mach-O 64-bit arm64" || { echo "keytar is not darwin arm64"; exit 1; }

step "electron-builder"
rm -rf dist
CSC_IDENTITY_AUTO_DISCOVERY=false pnpm exec electron-builder --config electron-builder.yml --publish never \
  -c.mac.hardenedRuntime=false -c.npmRebuild=false --mac dir --arm64
APP=dist/mac-arm64/LogseqDEV.app

step "ad-hoc sign"
cd "$CACHE/rcodesign"
[ -f rcs.tgz ] || { curl -fsSL -o rcs.tgz "$RCODESIGN_URL"; curl -fsSL -o rcs.sha256 "$RCODESIGN_URL.sha256"; }
echo "$(awk '{print $1}' rcs.sha256)  rcs.tgz" | sha256sum -c -
[ -x rcodesign ] || tar xzf rcs.tgz --strip-components=1
cd "$PKG/static"
"$CACHE/rcodesign/rcodesign" sign "$APP" 2>&1 | tail -2

step "copy app to project"
rm -f "$OUT"/LogseqDEV-darwin-arm64-*.zip "$OUT/SHA256SUMS"
rsync -a --delete "$APP/" "$OUT/LogseqDEV.app/"
step "done"
echo BUILD-OK
