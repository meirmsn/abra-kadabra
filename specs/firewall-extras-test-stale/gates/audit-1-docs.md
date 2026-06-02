Clean — no docs findings.

---

Audit notes (informational, not findings):

- Range touches only `kit/tests/firewall-extras-overlay.bats` (1 file, +11/-6) —
  a `kit/tests/**` change, an explicit carve-out in the devshop coverage rubric
  (Section A). No source/script/doc surface changed, so no docs-coverage
  obligation fires.
- Section A (Coverage): no reference docs touched; none required. No
  `**Existing projects:**` block needed — the range touches no
  propagation-relevant surface (`template/**`, `kit/scripts/**`, `kit/hooks/**`,
  `.devcontainer/**`, `kit/manifest.txt`, or a `[locked]`/`[sync]`/`[scaffold-once]`
  file). Clean.
- Section B (Adequacy): the test's new static-grep assertion was empirically
  verified against the live target. Command:
  `grep -qE '\[ -e "\$FWE_DST" \] && \[ "\$\(stat -c .%U:%G %a. "\$FWE_DST"\)" != "root:root 644" \]' kit/scripts/init-devshop.sh`
  → exit 0 (MATCH) against `init-devshop.sh:225`
  (`if [ -e "$FWE_DST" ] && [ "$(stat -c '%U:%G %a' "$FWE_DST")" != "root:root 644" ]; then`).
  The removed old unconditional form no longer matches (exit 1) — confirming the
  staleness this fix addresses. Full suite green: 16/16 pass, including the
  renamed test #14. Claim matches actual behavior.
- Section C (Coherence): no renamed/deleted files; no reference docs touched;
  no cross-doc contradictions. The in-test rationale comment correctly cites
  c6be31e as the shipping commit for the stat-drift guard.
- Section D (Bypass trailers): No Docs-Coverage-Bypass trailers in range.
- Section E (CLAUDE.md hygiene): skipped — devshop self-mode.
