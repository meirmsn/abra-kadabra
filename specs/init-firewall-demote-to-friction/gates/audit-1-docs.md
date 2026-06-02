Clean — no docs findings.

---

## Docs review notes (devshop self-mode; range c6be31e..86c448e)

Audit summary — high=0 medium=0 low=0. Recorded for the audit trail:

- **Section A (Coverage)** — no firing surfaces. The diff touches only carve-out
  paths: `PLAN.md`, `kit/TODOS.md`, `kit/FRICTION-LOG.md` (all trackers — explicit
  no-fire carve-outs), and one paragraph of `kit/docs/guide/ops.md` (guide-only,
  the audit owns guide commits). No `kit/scripts/**`, `template/**`,
  `.devcontainer/**`, `kit/hooks/**`, or `kit/manifest.txt` touched, so no
  surface→required-doc rule and no Existing-Project-Migration-Block rule fires.

- **Section B (Adequacy)** — substantive, not stub. Verified the key empirical
  claims in the FRICTION-LOG `init-firewall` analysis against the actual
  `.devcontainer/init-firewall.sh` source (read-only):
  - flush/destroy sequence claimed at "~L9–15" → confirmed: `iptables -F` (L9),
    `-X` (L10), `-t nat -F` (L11), `-t mangle -F` (L13), `ipset destroy
allowed-domains` (L15).
  - policy DROP claimed at "~L146–148" → confirmed: `iptables -P {INPUT,FORWARD,
OUTPUT} DROP` at L146–148.
  - ESTABLISHED,RELATED re-add claimed at "~L151–152" → confirmed: L151–152.
    The "atomic-ipset-swap targets the wrong layer; the flush/policy-flip window is
    the real suspect" analysis is internally consistent and matches the source.

- **Section C (Cross-doc coherence)** — the central coherence question (the
  repointed ops.md cross-reference) checks out, and no stale references to the
  removed entries survive anywhere in the reference doc set:
  - ops.md citation `kit/FRICTION-LOG.md § \`init-firewall.sh\` re-run mid-session
    hangs the Claude session` matches the FRICTION-LOG heading (line 304)
    **exactly**, backticks included.
  - The deleted `kit/TODOS.md` init-firewall-hang entry: the only doc that cited
    it (`ops.md`, "Tracked in kit/TODOS.md") is the one this PR repointed. No
    other reference doc (`CLAUDE.md`, `kit/docs/**`, `README.md`, `BUILD-LOG.md`)
    still cites it. The surviving `macos-host-setup.md:28` `kit/TODOS.md §`
    reference points at a _different_, still-present TODOS entry (Docker Desktop
    no-new-privileges) — not the deleted one.
  - Removed PLAN.md rows (`init-firewall-connection-preserving`,
    `ak-check-docs-orphan-stubs`): no surviving "still-pending" citation. PLAN.md
    `## Planned (v0)` now holds only `gstack-state-volume-backed` +
    `sudo-scoping-node`, table well-formed. `kit/docs/CHANGELOG.md`,
    `kit/docs/OVERVIEW.md`, `README.md` mention neither slug.
  - CLAUDE.md `§ Known Footguns` "Firewall IP rotation" (line 99) carries the
    "Don't re-run init-firewall.sh mid-session (stalls)" first-action and points
    at `ops.md § Firewall IP rotation` (heading present, ops.md:395). The
    FRICTION-LOG entry's claim (line 327) that the operator workaround "is already
    documented in /devshop/CLAUDE.md § Known Footguns and ops.md § Firewall IP
    rotation" is accurate — no operator guidance lost by demoting to observation.
  - New FRICTION-LOG `core.bare` entry's sibling cross-ref to the `[HIGH]
core.worktree` entry resolves (`kit/TODOS.md:10`). Its `--source-worktree`
    skill references resolve (`.claude/skills/ak-merge-devshop/SKILL.md:72`).
  - FRICTION-LOG remains score-sorted descending (12 → 8 → 4… → 1).

- **Section D (Bypass trailers)** — No Docs-Coverage-Bypass trailers in range.
  No CLAUDE-MD-Bypass trailers in range.

- **Section E (CLAUDE.md hygiene)** — skipped (project-mode-only; this is devshop
  self-mode). Informational: CLAUDE.md untouched in range, size stable (24801
  bytes at base and HEAD, +0).
