# cli-e2e

Shell-first end-to-end tests for logseq CLI.

## Test cli-e2e itself
- Run internal cli-e2e harness unit tests: `bb unit-test`

## cleanup first
- Execute cleanup: terminate stale db-worker-node processes, terminate stale db-sync listeners on port `18080`, and remove cli-e2e temp roots: `bb cleanup`
- Preview cleanup actions only (no kill/delete): `bb cleanup --dry-run`

## Run non-sync suite
- List declared non-sync case ids: `bb list-cases`
- Run non-sync cases with build preflight unless `--skip-build` is provided: `bb test`
  - `bb test --help` for options
  - Increase case-level parallelism with `--jobs N` (default: `4`), for example: `bb test --skip-build --jobs 4`
  - Parallelism is case-scoped only; each case still runs setup/main/cleanup sequentially in the existing ephemeral shell model
