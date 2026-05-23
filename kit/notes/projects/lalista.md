---
supabase_port_offset: 0
---

# Init Tracker — lalista

Created by manual migration on 2026-04-16.
Original record from `BUILD-LOG.md` init log (Phase 0b).

## Progress

1. [x] Check binary versions — all current (git-delta 0.19.2, supabase-cli 2.84.2, DCG 0.4.0, gitleaks 8.30.1)
2. [x] Customize project docs (BUILD-LOG.md, PRODUCT-ROADMAP.md, README.md)
3. [x] **[HUMAN]** Create accounts (Vercel, Sentry, PostHog, Supabase)
4. [x] **[HUMAN]** Fill .devcontainer/.env with credentials
5. [x] **[HUMAN]** Add GitHub Secrets + Variables
6. [x] **[HUMAN]** Add firewall domains to .devcontainer/init-firewall.sh
7. [x] **[HUMAN]** Rebuild devcontainer
8. [x] Disable turbo telemetry
9. [x] Install gstack
10. [x] Scaffold packages/core
11. [x] Scaffold packages/ui
12. [x] Scaffold apps/web
13. [x] Add Vercel CLI + link + pipe env vars
14. [x] Install Playwright
15. [x] Supabase init + link
16. [x] Create METRICS.md
17. [x] Run /setup-deploy
18. [x] Create project CLAUDE.md
19. [x] Enable doc enforcement hooks
20. [x] Update .gitleaks.toml allowlist
21. [x] **[HUMAN]** Lock security-critical files
22. [x] Create keepalive.yml
23. [x] **[HUMAN]** Set up service quota alerts
24. [x] **[HUMAN]** Enable branch protection
25. [ ] Run /cso baseline security audit

## Notes

- Step 3: Vercel (account + GitHub App installed), Sentry (project `lalista`), PostHog (project `lalista`), Supabase (pre-existing). Apple Developer deferred.
- Step 5: Secrets added (VERCEL_TOKEN, SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN, SENTRY_AUTH_TOKEN, NEXT_PUBLIC_POSTHOG_KEY) + PRODUCTION_URL variable.
- Step 10: `@lalista/core` — typed Supabase client factory, generated types. 1 test passed.
- Step 11: `@lalista/ui` — design tokens from DESIGN.md, Tailwind config. 4 tests passed.
- Step 12: Next.js 16.2.3, Tailwind v4, App Router, Sentry + PostHog, security headers, PWA manifest. 5 tests passing.
- Step 13: Vercel CLI installed, project linked, 5 env vars piped. Production URL: `lalista-ten.vercel.app`
- Step 14: Playwright 1.59.1 + Chromium. Mobile (375px) + desktop (1440px) projects.
- Step 26: Squash-only merges, auto-delete head branches. Branch protection: require PR, require `fast` status check, require linear history.

## Post-Init

- **Dependabot** (2026-04-13): Added `.github/dependabot.yml` — weekly npm security update PRs, minor+patch grouped. Resolves v0-gap #1.
