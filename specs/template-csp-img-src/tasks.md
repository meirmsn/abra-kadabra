# Tasks: template-csp-img-src

Devshop-self-mode: pure-doc edits. Test surface is bats (no new tests — see spec § Tests).

## Task: Pattern 2 img-src fold

**Hat**: PM (docs)
**Depends on**: none
**Blocks**: none
**Done when**: Pattern 2 IIFE computes one trimmed `supabaseUrl` and emits both `connect-src` and `img-src` lines; `img-src` reads `img-src 'self' data: blob: ${supabaseUrl}` with the D2 block-comment; `**Why:**` prose covers the img-src case.
**Risk**: low
**Status**: done

## Task: ### CSP convention sub-section

**Hat**: PM (docs)
**Depends on**: none
**Blocks**: none
**Done when**: `conventions.md` has a `### CSP` sub-section between Responsive + Theme and PWA, naming connect-src / img-src / conditional media-src as `$NEXT_PUBLIC_SUPABASE_URL`-derived, cross-referencing Pattern 2.
**Risk**: low
**Status**: done (placed between Responsive + Theme and PWA)

## Task: Template // Does NOT: pointer touch-up

**Hat**: PM (docs)
**Depends on**: none
**Blocks**: none
**Done when**: `next.config.ts` `// Does NOT:` header says "the Pattern 2 `connect-src` + `img-src` builders".
**Risk**: low
**Status**: done

## Decisions

- (none beyond D1-D4 resolved at spec time)
