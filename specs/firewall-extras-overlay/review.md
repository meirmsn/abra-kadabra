# Review — firewall-extras-overlay

## Audit 1: manual (2026-05-14)

<!-- audited-at: 54951ff7e537bcd0c938fbdcf49e3e85a55a6b2e -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=4 low=2

### Docs findings

- [medium] template/.devcontainer/firewall-extra-domains:33-35 — file footer instructs `sudo /usr/local/bin/init-firewall.sh` "safe to call repeatedly" — directly contradicts SKILL.md Step 6 + ops.md:313 + CLAUDE.md:98 ("known to hang the Claude session")
- [medium] kit/docs/guide/ops.md:301-313 + CLAUDE.md:98 — Known Footguns Firewall IP rotation entries don't name `firewall-extra-domains` as the canonical edit target for non-prod-URL allowlist additions
- [low] kit/docs/guide/security.md:41 — `.devcontainer/*` enumeration omits new `firewall-extra-domains` overlay file

### Tests findings

- [medium] template/.devcontainer/init-firewall.sh:144-181 — new firewall-extras read-loop (regex validation + warn/skip) has zero bats coverage; existing structural-invariants.bats / template-compose-isolation.bats grep-test other init-firewall.sh assertions, this is the natural home
- [medium] kit/scripts/init-devshop.sh:133-143 — new seed-if-missing + chown-on-every-start block has zero bats coverage; security-relevant (drops `-o root -g root` would silently weaken posture)
- [low] kit/manifest.txt:83 — new `[scaffold-once]` entry has no specific assertion in manifest-lifecycle.bats (generic guards would catch wholesale breakage)

### Bypass trailer audit

- 1b30217 Docs-Coverage-Bypass: zero-match grep across 20 reference docs for `project_id|supabase init` — VERIFIED (re-ran grep at HEAD; zero matches; substitution recipe lives only in /ak-new-project skill)
- d7a44a1 Docs-Coverage-Bypass: zero-match grep across 20 reference docs for `devcontainerId|localWorkspaceFolderBasename|claude-code-bashhistory|claude-code-config` — VERIFIED (re-ran grep at HEAD; zero matches; bug-fix to existing inline-comment promise)
- (none) Tests-Coverage-Bypass — bypass mechanic is forward-compat; legitimately zero rows

## Audit 2: manual (2026-05-14)

<!-- audited-at: 27431907c2b5fadba9be119b8568941e56e895f9 -->
<!-- range: 54951ff7e537bcd0c938fbdcf49e3e85a55a6b2e..HEAD -->

findings: high=0 medium=0 low=0

Clean — all Audit 1 findings (4 medium / 2 low) addressed by 2743190.

### Docs findings

- (none) — Audit 1's contradicting-footer + missing-overlay-mention + security.md-enumeration findings all resolved. Reference docs (CLAUDE.md, ops.md, security.md) updated with consistent recalibrated framing per operator pushback that the original hang observation may be stale post-refresh-allowed-ips.sh.

### Tests findings

- (none) — Audit 1's missing-bats-coverage findings (init-firewall.sh extras read loop + init-devshop.sh seed/lock + manifest [scaffold-once]) all addressed by the new 16-test `kit/tests/firewall-extras-overlay.bats`. All green. Includes regression guard against "safe to call repeatedly" returning to the footer.

### Bypass trailer audit

- (none) Docs-Coverage-Bypass — no bypass trailers in range
- (none) Tests-Coverage-Bypass — no bypass trailers in range
