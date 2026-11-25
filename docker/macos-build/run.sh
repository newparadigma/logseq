#!/bin/bash
# Builds Blocklog for macOS ARM64 in Docker from this project folder and
# installs it into /Applications.
#   docker/macos-build/run.sh             build + install
#   docker/macos-build/run.sh --no-install
#   docker/macos-build/run.sh --install-only   install the last built app
# Do not edit the project while a build runs: the container works in this
# working tree (node_modules, static/, .shadow-cljs, cli/_build are written).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=logseq-macos-builder:local
VOLUME=logseq-macos-build-cache
NAME=logseq-macos-build
OUT=$ROOT/.tmp/macos-build
BUILT_APP=$OUT/Blocklog.app
IMAGE_TAR=$ROOT/docker/macos-build/image/logseq-macos-builder.tar.gz
APP=/Applications/Blocklog.app
mode=${1:-build-and-install}

mkdir -p "$OUT"
if [ "$mode" != "--install-only" ]; then
LOG=$OUT/build-$(date +%Y%m%d-%H%M%S).log

# Image: local Docker, else the saved copy in the project, else build it.
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  if [ -f "$IMAGE_TAR" ]; then
    gunzip -c "$IMAGE_TAR" | docker load
  else
    docker build -t "$IMAGE" "$ROOT/docker/macos-build"
  fi
fi
docker volume inspect "$VOLUME" >/dev/null 2>&1 || docker volume create "$VOLUME" >/dev/null

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
cleanup

start=$(date +%s)
echo "Building, log: $LOG"
docker run --rm --name "$NAME" \
  -v "$VOLUME":/work \
  -v "$ROOT":/work/src \
  "$IMAGE" bash /work/src/docker/macos-build/build.sh 2>&1 | tee "$LOG" | grep --line-buffered -E '^== |BUILD-OK|rror' || true
grep -q BUILD-OK "$LOG" || { echo "Build failed, see $LOG"; exit 1; }
echo "Build took $(( $(date +%s) - start ))s"
fi

[ "$mode" = "--no-install" ] && exit 0
if pgrep -f "$APP/Contents/MacOS/Blocklog" >/dev/null; then
  echo "Blocklog is running: quit it, then install with: $0 --install-only"
  exit 1
fi
tmp=/Applications/.Blocklog-install
rm -rf "$tmp"; mkdir "$tmp"
ditto "$BUILT_APP" "$tmp/Blocklog.app"
codesign --verify --deep --strict "$tmp/Blocklog.app"
[ -d "$APP" ] && mv "$APP" "$HOME/.Trash/Blocklog-$(date +%Y%m%d-%H%M%S).app"
mv "$tmp/Blocklog.app" "$APP"
rmdir "$tmp"
touch "$APP"
codesign --verify --deep --strict "$APP"
echo "Installed $APP (previous version moved to the Trash)"
