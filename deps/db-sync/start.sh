#!/usr/bin/env bash
set -euo pipefail

: "${DB_SYNC_PORT:=8787}"

# Sign-in token settings: run `node scripts/selfhost-token.mjs env <dir>`.
: "${AUTH_ISSUER:?set AUTH_ISSUER}"
: "${AUTH_CLIENT_ID:?set AUTH_CLIENT_ID}"
: "${AUTH_JWKS_URL:?set AUTH_JWKS_URL}"

export DB_SYNC_PORT
export AUTH_ISSUER
export AUTH_CLIENT_ID
export AUTH_JWKS_URL

node worker/dist/node-adapter.js
