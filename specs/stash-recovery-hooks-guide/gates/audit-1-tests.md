# Tests review — Audit 1

**Range**: `88a4bb6fca26de63a4974c06d10068e25c8f044c..84a9ac683278699a60f897dee8e1cc57583d47b0`
**Feature dir**: `specs/stash-recovery-hooks-guide`

## Scope

Single commit, pure-docs follow-up. Diffstat: 5 files, +67/-23. Files touched:

- `kit/docs/guide/hooks.md` — new lint-staged config block + "Recovering a vanished stash" recipe
- `CLAUDE.md` — Known Footguns pointer entry
- `.claude/skills/devshop/merge-devshop/SKILL.md` — hypothesis paragraph rewrite under § Known limitations
- `kit/notes/migration-info-loss-audit.md` — inline annotation on one row
- `kit/TODOS.md` — closes one shipped entry; rescopes the silent-stash-drop entry

Zero scripts changed (no `kit/scripts/**.sh`, no `kit/hooks/**`, no `kit/scripts/preship/**.sh`).
Zero test files touched (no `*.bats`, no `*.spec.ts`, no `*.test.ts`).
Zero template surface touched.
Zero new wrappers in `packages/core/src/api/**`.
Zero new E2E specs.
Zero new RPCs, edge functions, or realtime subscribers.

## Section A — Coverage of new behavior

**N/A.** No executable code introduced. All edits are documentation guidance, recipe text, tracker entries, and a SKILL.md hypothesis paragraph. None of the Section A rubric items (project-side or devshop-side) trigger: no scripts requiring `.bats`, no new SKILL.md requiring `util-<skill>.bats` smoke, no API wrappers, no `page.tsx` / `route.ts`, no RPCs, no edge functions, no `posthog.capture` / `Sentry.captureException` call sites, no realtime subscriptions.

Coverage map: empty.

## Section B — Test quality

**N/A.** No new or modified tests in the diff range. None of the quality sub-rubrics apply: no assertions to weaken/strengthen, no auth boundaries to verify, no shape-only assertions, no WebKit form-state hydration paths, no `routeWebSocket` patterns, no LLM/edge-function boundary parsing, no skipped/`.only` tests.

Quick-scan confirmation:

```
$ git diff --diff-filter=AM 88a4bb6..84a9ac6 -- '*.spec.ts' '*.test.ts' '*.test.tsx' '*.bats'
(no output)
```

## Section C — Bypass trailer audit

**Zero rows harvested.** No `Tests-Coverage-Bypass:` trailer in the commit message. The bypass mechanic isn't load-bearing here because the commit produces no testable executable surface — the deterministic Layer-1 hook (`check-tests-coverage-devshop.sh`) doesn't fire on pure-docs diffs, so no bypass was needed.

## Verdict

Tests look solid — no findings. high=0 medium=0 low=0
