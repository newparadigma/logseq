# Vendored Git dependencies

This directory contains the Git dependencies used by this Logseq checkout,
including development tasks, test runners, and the iOS Drops library. Separate
GitHub forks and Git submodules are not required.

`manifest.json` records each upstream repository, the original pinned ref, its
full commit SHA, the source archive SHA-256, and the retained top-level paths.
The initial snapshots match the dependencies of Logseq commit
`8bcad1f273f9ebced4d5bf161ccbee29ff136ff3`; Drops retains tag `1.7.0`.

## Contents

| Libraries | Purpose |
| --- | --- |
| datascript, clj-fractional-indexing, logseq-schema | Graph data and schema |
| hsx, rfx | Application UI |
| cljs-time, cljc-fsrs, glogi, malli | Dates, spaced repetition, logging, validation |
| bb-tasks, carve, clj-kondo-bb | Development tasks and their Git dependencies |
| nbb-logseq, nbb-test-runner, test-runner, wally | Scripts and tests |
| Drops | iOS alerts |

Only the source paths, resources, and available upstream license/readme files
needed to consume these libraries are retained. Upstream examples, tests,
release tooling, and development aliases are omitted. Runtime source files are
unchanged. Existing dependency versions and exclusions are preserved.

Clojure manifests use `:local/root`, relative to the containing manifest.
Vendored Clojure manifests retain their runtime dependencies and source paths;
their transitive Git dependencies also use local paths. The iOS Podfile uses
Drops as a local development pod. Its original podspec is unchanged.

`nbb-logseq` retains the upstream package's ready-to-run JavaScript, entry points,
and license/readme. Its consumers use pnpm `file:` dependencies. Its sole npm
dependency, `import-meta-resolve`, is pinned to `4.1.0`, the version already used
in all six consumer lockfiles. Rebuilding the interpreter itself is outside this
snapshot's scope.

Available upstream license files are retained. The cljs-time license statement
is in its README. No license file was present in the pinned logseq-schema source.

## Scope

The application, sync server, scripts, and tests consume these Git dependencies
from this repository. npm, Maven/Clojars, CocoaPods registry dependencies, runtime
downloads, and toolchains still require their normal package sources or caches.
This is not a fully offline build environment.

## Updating a library

1. Obtain the intended upstream commit and verify its source archive.
2. Replace the library's retained paths, preserving its license files.
3. Keep runtime Git dependencies local and inspect any new transitive dependency.
4. Update `manifest.json` with the commit and archive checksum.
5. For nbb-logseq changes, refresh and verify all six consumer pnpm lockfiles.
6. Resolve the application, server, and test dependency graphs, then run the
   affected builds and tests. Typical checks include:

   ```sh
   clojure -P -M:cljs
   pnpm --dir deps/common install --frozen-lockfile --ignore-workspace
   pnpm --dir deps/common test
   pnpm --dir deps/db-sync build:node-adapter
   ```

To undo this migration, restore the original Git coordinates and lockfiles along
with the original Drops Podfile entry, then remove this directory. Do not mix a
vendored source tree with manifests or lockfiles from before the migration.
