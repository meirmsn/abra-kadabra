# Gate 1: docs-check

**Verdict: pass**

## Checked surfaces

| Doc | Relevant section | Status | Notes |
|-----|-----------------|--------|-------|
| `kit/docs/guide/hooks.md` | Short-circuits list (line 211) | Updated in diff | New bullet documents the hash-cache fast path: storage location, invalidation semantics, perf savings, test pointer. |
| `CLAUDE.md` | Known Footguns -- "Pre-push blocks PR text-hygiene failures" | No update needed | Entry describes the footgun (what blocks + bypass flags) and delegates short-circuit enumeration to `hooks.md`. Does not enumerate the pre-existing SHA-enumeration fast path either -- consistent. |
| `kit/docs/OVERVIEW.md` | ASCII art pre-push flow (lines 170-189) | No update needed | Structural overview does not enumerate short-circuits at this abstraction level. |
| `kit/docs/guide/conventions.md` | Enforcement-routing table (line 503) + Hygiene-Override trailer (line 822) | No update needed | These describe where the check fires and what trailers it emits, not short-circuit paths. |
| `kit/docs/guide/hooks.md` | "On Push" narrative (line 381) | No update needed | Higher-level prose; individual short-circuits are enumerated in the structured list, not the narrative paragraph. Consistent with the SHA-enumeration path not appearing here either. |

## Dismissals

None
