# Review — slow-job-active-from-scaffold

## Audit 1: manual (2026-05-14)

<!-- audited-at: 52a01f89e6218f8c7866f65586bce3592edd5048 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] kit/ROADMAP.md (new "CI slow-job lifecycle convention — ship active from day one" entry's Cross-ref bullets) — two cited line ranges are stale: `/ak-new-project SKILL.md:967-989` (Step 24 actually at line 1196, deferral language at 1203-1219); `template/ci.yml:75-113 + 142+` (`# changes:` at 94 OK; `# slow:` at 142, outside the 75-113 range). Cross-ref pointers will misdirect the implementer by one grep round-trip; section anchors (`§ Step 24`, `§ slow:`) still resolve correctly so impact is minor. Fix: update line numbers or drop them in favor of section anchors which don't rot.

### Tests findings

- (none) — pure docs change to kit/ROADMAP.md; no source / test files in range.

### Bypass trailer audit

- (none) Docs-Coverage-Bypass — no bypass trailers in range
- (none) Tests-Coverage-Bypass — no bypass trailers in range
