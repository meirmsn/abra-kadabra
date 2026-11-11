# The reviewer's workspace fixture

A pnpm workspace whose site must be built before it is served
([spec](../../../specs/reviewer-local-run-build.md)), used by `tests/reviewer.test.sh`. `base/` is
the project: `apps/web` depends only on `@fixture/site-tool`, a workspace package two levels deep
(`packages/tools/site-tool`) with a bin, so `pnpm install --offline --frozen-lockfile` needs no
network and no store, and the tool is found from `apps/web` only through the
`apps/web/node_modules/.bin` pnpm creates. `scripts/build.sh` writes `apps/web/dist/` and
`scripts/local-run.sh` serves it. Each other directory holds the files a variant replaces:
`build-fails/` (exits 1), `build-slow/` (never finishes), `build-leaves-child/` (exits 0 with a
background process left) and `lockfile-mismatch/` (a dependency the lockfile lacks).
