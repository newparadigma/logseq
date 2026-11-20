#!/usr/bin/env node
// Issues sign-in tokens for a self-hosted db-sync server, so the apps can
// sync without a Logseq account. The server checks the tokens with its
// existing JWT verification (COGNITO_* settings), no server code is involved.
//
//   node selfhost-token.mjs init <dir> --issuer https://sync.example.com/ --username me [--email me@example.com]
//   node selfhost-token.mjs env <dir>      # COGNITO_* lines for the server .env
//   node selfhost-token.mjs token <dir> [--days 3650]
//
// <dir> holds the private signing key: anyone who has it can sign in as you.

import { createPrivateKey, createPublicKey, generateKeyPairSync, randomUUID, sign } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const CLIENT_ID = "logseq-selfhost";

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const [command, dir, ...rest] = argv;
  const options = {};
  for (let i = 0; i < rest.length; i += 2) {
    if (!rest[i].startsWith("--") || rest[i + 1] === undefined) fail(`bad argument: ${rest[i]}`);
    options[rest[i].slice(2)] = rest[i + 1];
  }
  if (!command || !dir) fail("usage: selfhost-token.mjs init|env|token <dir> [options]");
  return { command, dir, options };
}

const b64url = (data) => Buffer.from(data).toString("base64url");

function readSettings(dir) {
  const settingsPath = join(dir, "settings.json");
  if (!existsSync(settingsPath)) fail(`${settingsPath} not found, run init first`);
  const settings = JSON.parse(readFileSync(settingsPath, "utf8"));
  const privateKey = createPrivateKey(readFileSync(join(dir, "private.pem"), "utf8"));
  return { settings, privateKey };
}

function init(dir, { issuer, username, email }) {
  if (!issuer || !/^https?:\/\//.test(issuer)) fail("--issuer must be an http(s) URL");
  if (!username) fail("--username is required");
  if (existsSync(join(dir, "private.pem"))) fail(`${dir} already has a key; delete it to start over`);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  writeFileSync(join(dir, "private.pem"), privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
  // sub is the user id on the server: every token for every device must share it.
  const settings = { issuer, kid: randomUUID(), sub: randomUUID(), username, email: email || null };
  writeFileSync(join(dir, "settings.json"), JSON.stringify(settings, null, 2) + "\n", { mode: 0o600 });
  printEnv(dir);
}

function printEnv(dir) {
  const { settings, privateKey } = readSettings(dir);
  const jwk = createPublicKey(privateKey).export({ format: "jwk" });
  const jwks = { keys: [{ ...jwk, kid: settings.kid, alg: "RS256", use: "sig" }] };
  // Node's fetch reads data: URLs, so the server needs no extra host for its keys.
  console.log(`COGNITO_ISSUER=${settings.issuer}`);
  console.log(`COGNITO_CLIENT_ID=${CLIENT_ID}`);
  console.log(`COGNITO_JWKS_URL=data:application/json,${encodeURIComponent(JSON.stringify(jwks))}`);
}

function token(dir, { days = "3650" }) {
  const { settings, privateKey } = readSettings(dir);
  const lifetimeDays = Number(days);
  if (!Number.isInteger(lifetimeDays) || lifetimeDays <= 0) fail("--days must be a positive integer");
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT", kid: settings.kid };
  const payload = {
    iss: settings.issuer,
    aud: CLIENT_ID,
    sub: settings.sub,
    "cognito:username": settings.username,
    ...(settings.email ? { email: settings.email, email_verified: true } : {}),
    token_use: "id",
    iat: now,
    exp: now + lifetimeDays * 24 * 60 * 60,
  };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signature = sign("RSA-SHA256", Buffer.from(signingInput), privateKey);
  console.log(`${signingInput}.${b64url(signature)}`);
}

const { command, dir, options } = parseArgs(process.argv.slice(2));
if (command === "init") init(dir, options);
else if (command === "env") printEnv(dir);
else if (command === "token") token(dir, options);
else fail(`unknown command: ${command}`);
