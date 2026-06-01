## Gate 1: docs-check

**Verdict: pass.** Every devshop behavior change in `git diff origin/main..HEAD` carries a same-change doc update; in-script comments are accurate; the architecture.md § File lifecycle description is consistent with the new conditional-refresh behavior; and the cross-doc survey for stale "every container start" / "always-chown" phrasing found no doc that _misdescribes_ the post-fix behavior.

### (1) Behavior change ↔ doc coverage (same change)

The diff has exactly two behavior changes, both documented in-change:

- **Content-conditional `[locked]` refresh** (`cmp -s "$src" "$dst"` gates the `install`) → covered by the architecture.md table `[locked]` row rewrite ("content-conditionally refreshed every container start … a content match is a true filesystem no-op, so a quiet boot never bumps mtime") and the in-script comment block + inline comments.
- **Ownership-conditional chown/chmod lock steps** (`stat -c '%U:%G %a'` tuple guard on all five lock sites: manifest content-match branch, firewall-extras lock, devshop-self for-loop, recursive `find` over kit scripts, and the devshop-self-mode early-exit branch) → covered by the architecture.md hybrid-lifecycle paragraph rewrite ("re-locks it … ownership-conditionally — the chown/chmod runs only when the `stat -c '%U:%G %a'` tuple has drifted") and the in-script comment block.

Two new bats regression tests (`manifest-lifecycle.bats`) statically pin both guards. Spec § Files-to-modify also calls for deleting the `kit/TODOS.md` entry that scoped this — not in this diff's file set; flagged below as a tracker-closure item to confirm (outside this gate's grep-on-`kit/docs`+`CLAUDE.md` mandate, noted for the merge step).

### (2) In-script comment accuracy

Accurate. The comment block (added ~after the early-exit branch) says "Every chown/chmod lock step **below**" and enumerates the four sites that follow it (manifest content-match branch, firewall-extras lock, devshop-self for-loop, recursive find). The fifth guarded site (the devshop-self-mode early-exit `settings.json`/`.dcg.toml` loop) sits _above_ the block and is separately commented ("Lock essentials even in devshop-self mode"), so the "below" scoping is correct, not an omission. The inline comments at the `install`/`else` branch correctly state the `install` is the script's only mtime-bumping write and that the `else` branch still recovers ownership/mode a git op eroded. The `cmp -s` exits-2-on-missing-dst behavior (preserving first-propagation) is correctly captured in both the inline comment and spec § Out-of-scope.

### (3) architecture.md § File lifecycle consistency

Consistent. Both the `[locked]` annotation-table row and the Hybrid-lifecycle paragraph were rewritten from the old unconditional framing to the conditional framing, and they agree with the script: refresh gated on content (`cmp -s`), lock gated on ownership tuple (`stat`). No internal contradiction between the two updated passages or with the script.

### (4) Cross-doc stale-phrasing survey (grep over kit/docs/ + CLAUDE.md)

Grepped for `every container start`, `every start`, `refreshed on every`, `chown … on every`, `always-chown`, `overwrite … on every`, `re-?lock … every`. Hits triaged below. **None misdescribe the post-fix behavior** — every survivor describes the lifecycle _guarantee_ (the locked copy is kept current from template / ends up root-owned), which the conditional refresh preserves exactly (a content-match is a no-op _because_ content already matches; an ownership-match is a no-op _because_ ownership already matches). None makes an mtime / always-write claim that the fix invalidated.

In-scope `[locked]`-refresh mentions (survivors, all accurate):

- `kit/docs/FAQ.md:25` — "root-owned copies refreshed every container start". Compressed lifecycle-bucket summary; no mtime/always-write claim. Accurate. _(Borderline — see optional polish below.)_
- `kit/docs/guide/architecture.md:176` — sync-exclude context, "refreshed every container start by init-devshop.sh". Describes which lifecycle bucket the leaves belong to (for the exclude rationale). Accurate.
- `kit/docs/guide/security.md:39` — "refreshed from template by init-devshop.sh on every container start". Lifecycle-bucket altitude; guarantee holds. Accurate. _(Borderline — see optional polish below.)_
- `kit/docs/guide/workflow.md:421` — firewall-extra-domains "locked to root:root 644 on every container start"; "reverts on every start". Describes the lock invariant; the ownership-conditional guard preserves the end-state. Accurate.
- `kit/docs/guide/ops.md:405` — firewall-extra-domains "chowned root:root 644 on every container start". Same lock invariant. Accurate.
- `kit/docs/guide/ops.md:326` — buggy `init-firewall.sh` self-heal: "overwrites the project's copy from the fixed template on every container start". The buggy file _differs_ from the fixed template → `cmp -s` mismatches → `install` fires → self-heal still works. Outcome unchanged and correct; the "every start" is the recovery guarantee, not an mtime claim. Accurate.

Out-of-scope hits (different subsystems, not `[locked]` refresh — listed to show they were checked, not flagged): `architecture.md:91` (port-derive), `ops.md:114` (compose env), `ops.md:281` (init-firewall run), `ops.md:305` (compose port interpolation), `ops.md:503` (playwright-cache populate), `local-supabase-compose-isolation.md:53` (init-host-env), `CLAUDE.md:170` / `workflow.md:323`/`487` (unrelated "every" matches). None describe the `[locked]` install/lock cadence.

### Optional, non-blocking polish (NOT required for this gate to pass)

Two summary-altitude lines could optionally pick up the same one-clause "content-/ownership-conditional" qualifier the architecture.md canonical passages now carry, purely for symmetry — they are **not stale** (no mtime claim to falsify) and are explicitly outside the spec's scoped doc-update set:

- `kit/docs/FAQ.md:25` — could read "content-conditionally refreshed every container start" to mirror the table.
- `kit/docs/guide/security.md:39` — could note the refresh is content-conditional.

These are author-discretion improvements, not findings. Surfaced for the merge author; no halt.

## Dismissals

None.
