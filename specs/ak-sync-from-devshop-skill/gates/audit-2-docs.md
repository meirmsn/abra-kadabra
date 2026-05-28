Clean — no docs findings.

---

**Audit 2 (docs) — re-audit notes (informational, not findings):**

Range: f97b7df..HEAD (devshop self-mode). Two commits — the Audit 1 record
commit + the fix commit `43f7fe8` (closed Audit 1's 4 medium findings).

Section A (coverage): no source surfaces touched. Range modifies only docs
(`CLAUDE.md`, `kit/docs/guide/architecture.md`), tests (`kit/tests/**` —
carve-out, no firing), and `specs/**` artifacts. No `kit/scripts/**`,
`kit/hooks/**`, `template/**`, `.devcontainer/**`, `kit/manifest.txt`, or
`SKILL.md` surface in range → no source-change-without-doc finding, and the
Existing-Project Migration Block check does not fire (no propagation-relevant
surface). Coverage clean.

Section B (adequacy): both doc edits are substantive (not whitespace/reflow
stubs) and their named-mechanism claims verify empirically:

- CLAUDE.md § Session Start "the reminder points operators at
  `/ak-sync-from-devshop`" — confirmed: `kit/scripts/session-start.sh:189,194`
  both emit `run /ak-sync-from-devshop`.
- CLAUDE.md + architecture.md "filters `kit/docs/PROPAGATION.md` to the synced
  version range" — confirmed: skill Phase 3 (SKILL.md:110,119) parses
  `## v{x.y.z}` headers and filters by semver.
- architecture.md "wraps the script below … runs automatable propagation
  audits inline" — confirmed: skill Phase 2 wraps `from-devshop.sh --yes`,
  Phase 3 offers to run ◐ automatable audits.
- Cited skill `/ak-sync-from-devshop` exists
  (`.claude/skills/devshop/sync-from-devshop/SKILL.md`); cited
  `kit/docs/PROPAGATION.md` exists. No dangling references.

Section C (coherence): Audit 1's two coherence findings (CLAUDE.md and
architecture.md under-describing the operator path) are RESOLVED — all three
canonical sync references now consistently route to `/ak-sync-from-devshop`
(workflow.md § Devshop Skill Map row, CLAUDE.md § Session Start,
architecture.md § Propagating build tooling updates). Stale-framing sweep:
no reference doc still carries the retired "No manual reads needed" /
"`from-devshop.sh` prints a pointer" two-step framing. `conventions.md`'s
`from-devshop.sh` mentions are in unrelated contexts (gitignore enforcement,
Existing-Project Migration Block trigger table) and correctly reference the
script as the underlying sync mechanism — not stale. No renamed/deleted files
in range. Coherence clean.

Section D (bypass trailers): No Docs-Coverage-Bypass trailers in range.

Section E (CLAUDE.md hygiene): skipped — devshop self-mode.
