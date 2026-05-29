# Review — csp-img-src-and-worktree-recovery

## Audit 1: manual (2026-05-28)

<!-- audited-at: 83e740cea18cdd3adb98feb3d9659d6c03d0a594 -->
<!-- range: d50fb41d11bc63686d2970e3c9c96baf84c039cb..83e740cea18cdd3adb98feb3d9659d6c03d0a594 -->

findings: high=0 medium=1 low=1

### Docs findings

- [medium] kit/ROADMAP.md:425 (§ Template CSP `img-src`) — entry names a `buildConnectSrc()` template function that does not exist; real pattern is the anonymous `connect-src` IIFE in supabase-ssr-boilerplate.md § Pattern 2, and template next.config.ts ships no CSP block yet (Pattern 2 is future work).
- [low] kit/ROADMAP.md:427-428 (§ Template CSP `img-src`) — "prod unchanged because `https:` already covers it" rests on a `https:` token the canonical Pattern 2 `img-src` (`'self' data: blob:`) does not contain; appended Supabase origin is load-bearing in prod too.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-28)

<!-- audited-at: 3c25c96f5d313dea6d536ee3561ef901d45b9c09 -->
<!-- range: 83e740cea18cdd3adb98feb3d9659d6c03d0a594..3c25c96f5d313dea6d536ee3561ef901d45b9c09 -->

findings: high=0 medium=0 low=0

### Docs findings

- (none) — Audit 1's medium+low both resolved by 3c25c96; corrected claims verified against repo reality (no buildConnectSrc()/buildImgSrc() anywhere; Pattern 2 img-src is `'self' data: blob:` with no `https:`; template ships no CSP block yet).

### Tests findings

- (none)

### Bypass trailer audit

- (none)
