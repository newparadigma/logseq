# syntax=docker/dockerfile:1

# Self-hosted Logseq page publish server (Node.js adapter from deps/publish).
# Built from this repository checkout: the build context is the repository
# root (see docker-compose.yml), so the server renders pages with the same
# code as the apps built from the same commit. Dockerfile.dockerignore keeps
# the context small.
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
ARG PNPM_VERSION=10.33.0

# Compilers only for better-sqlite3 when no prebuilt binary is available
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/include/node /usr/local/include/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && npm install -g "pnpm@${PNPM_VERSION}"

WORKDIR /src/deps/publish

# npm packages first, so source changes do not reinstall them
COPY deps/publish/package.json deps/publish/pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile --ignore-workspace

# Clojure sources: publish and the local libraries it depends on
COPY deps /src/deps
COPY resources /src/resources

# Release build of the Node adapter. Maven jars stay in a build cache
# (shared with the sync server image), so a source change does not
# download them again.
RUN --mount=type=cache,id=logseq-sync-m2,target=/root/.m2 \
    clojure -M:cljs release publish-node \
 && test -s worker/dist/node-server.js

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM node AS runtime

LABEL org.opencontainers.image.title="logseq-publish" \
      org.opencontainers.image.description="Self-hosted Logseq page publish server"

# Sign-in uses self-issued tokens: AUTH_ISSUER, AUTH_CLIENT_ID and
# AUTH_JWKS_URL come from docker-compose (.env). Published pages stay here.
ENV NODE_ENV=production \
    PUBLISH_PORT=8788 \
    PUBLISH_DATA_DIR=/data \
    PUID=1000 \
    PGID=1000

WORKDIR /app
COPY --from=build /src/deps/publish/node_modules ./node_modules
COPY --from=build /src/deps/publish/worker/dist/node-server.js ./worker/dist/node-server.js

# Starts as root only to prepare the data folder, then drops to PUID:PGID,
# so files in the bind-mounted folder belong to your user on the host.
COPY --chmod=755 <<'SCRIPT' /usr/local/bin/logseq-publish-entrypoint
#!/bin/sh
set -eu
mkdir -p "$PUBLISH_DATA_DIR"
if [ "$(id -u)" = "0" ]; then
  if [ "$(stat -c %u:%g "$PUBLISH_DATA_DIR")" != "$PUID:$PGID" ]; then
    chown -R "$PUID:$PGID" "$PUBLISH_DATA_DIR"
  fi
  exec setpriv --reuid="$PUID" --regid="$PGID" --clear-groups "$@"
fi
exec "$@"
SCRIPT

EXPOSE 8788
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PUBLISH_PORT+'/').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"

ENTRYPOINT ["logseq-publish-entrypoint"]
CMD ["node", "/app/worker/dist/node-server.js"]
