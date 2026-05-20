### [domain: docs] [section: C] [severity: low]

**File**: kit/docs/OVERVIEW.md:262
**What**: OVERVIEW.md's one-line notifications summary ("push alerts to iPhone/Watch/Mac via ntfy.sh, 30s debounce, privacy, rotation") doesn't mention the new "suppression when Claude scheduled deferred work" topic that's now a peer-level `## ` heading in `guide/notifications.md`.
**Why**: Minor coherence drift — OVERVIEW's pointer is a topic-keyword list and now under-represents the doc. Not load-bearing; the link still resolves to the right place.
**Fix**: Append `, deferred-work suppression` (or similar) to the OVERVIEW.md notifications summary line so the keyword index stays current with the doc's section list.

### [domain: docs] [section: D] [severity: low]

**File**: commit fd271f3 (Docs-Coverage-Bypass trailer)
**What**: Bypass trailer VERIFIED — claim "the right doc IS staged (kit/docs/guide/notifications.md gains the new 'Suppression when Claude scheduled deferred work' section + 'The devshop is also a devcontainer' paragraph)" verified against the staged diff; per-doc affected/not-affected enumeration (CLAUDE.md / workflow / conventions / hooks / architecture / security / ops / supabase-ssr-boilerplate all marked NOT AFFECTED) is accurate; the named-phrases-against-diff check passes for both AFFECTED edits; and the catalog gap the bypass cited as session learning was closed in the very next commit (3fbde1f). No escalation.
**Why**: Informational record only; bypass-trailer audit per § Section D requires recording VERIFIED outcomes.
**Fix**: None — recorded.

## Bypass Trailer Audit Summary

- `Docs-Coverage-Bypass:` (fd271f3) → **VERIFIED**. Catalog-gap rationale was load-bearing AND closed in 3fbde1f within the same range; the right canonical doc (`kit/docs/guide/notifications.md`) was staged.
- `CLAUDE-MD-Bypass:` → none in range.

## Summary

- Coverage (Section A): clean. All touched surfaces have matching canonical doc edits staged in the same range; the one bypass trailer in range is a catalog-gap rationale, not a real coverage miss, and the gap was closed in the same range (3fbde1f).
- Adequacy (Section B): clean. The new `## Suppression when Claude scheduled deferred work` section names the three suppressing tools (ScheduleWakeup / CronCreate / Bash|Agent + `run_in_background:true`), matches the script's jq selector verbatim, and the TOC entry was added with the correct anchor. The "devshop is also a devcontainer" paragraph cites a real verifiable check (`echo "$NTFY_URL"`) and a real file path (`/devshop/.devcontainer/.env`).
- Coherence (Section C): one low finding (OVERVIEW.md topic-summary line under-represents the new section).
- Bypass audit (Section D): one VERIFIED trailer recorded; no escalations.
- Section E: skipped (devshop self-mode; project-mode-only gate per skill spec).

high=0 medium=0 low=2
