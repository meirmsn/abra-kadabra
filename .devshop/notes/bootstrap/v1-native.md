# Dev-Shop Native Plan (Deferred)

> This document preserves all native/mobile planning from the original devshop plan (v0-web.md).
> The team decided to go web-first: build the devshop for web apps, validate with lalista web,
> then add native capability. This document is the reference for that second phase.
>
> **Prerequisite**: Web devshop must be validated (Phase 0b checkpoint passing) before starting native work.

---

## 1. Architecture Decisions (Native)

_Extracted from: v0-web.md → "Architecture Decisions (With Rationale)"_

### Why Expo SDK 52 + React Native?

- Cloud iOS builds via EAS Build — no Xcode in CI, no Mac needed for builds
- OTA updates (EAS Update) bypass App Store review for JS-only changes — critical for fast bug fixes
- Expo Router mirrors Next.js patterns — one mental model for both apps
- Expo Modules API enables native Swift modules without ejecting — needed for Siri
- Same codebase builds iOS, Android, and Mac (Catalyst) — no dead ends for future surfaces

### Why NOT bare React Native (without Expo)?

More manual setup, no managed cloud builds, no OTA updates. No meaningful gain for a solo dev.

### Why NOT NativeWind? (Decision: dropped)

NativeWind v4 was evaluated and rejected. Its failures are **silent** — unsupported Tailwind classes are ignored with no error, no warning. Debugging requires visual inspection of every screen on every platform. It also requires Babel plugin ordering, extra `.npmrc` hoisting, and Metro config patches — three layers of tooling to patch tooling. This contradicts the project's "failures must be loud" and "simplest solution" principles.

### Mobile styling approach: StyleSheet.create + shared tokens

`packages/ui/src/tokens.ts` is the single source of truth for design tokens (colors, fonts, spacing). Web uses Tailwind CSS with a `tailwind.config.js` that imports from `tokens.ts`. Mobile uses `StyleSheet.create` importing from `tokens.ts` directly. The design system is unified through tokens, not class names. Web: `className="bg-terracotta"`. Mobile: `style={styles.bgTerracotta}`. Both resolve to the same `#D4603A` from `tokens.ts`.

See v0-web.md Phase 0b Step 2 for `packages/ui` token setup.

### Why Jest for mobile?

Vitest is faster and TS-native for Next.js. Expo ships with Jest pre-configured — changing it adds friction. Both support the same testing patterns.

### Why Maestro for mobile E2E?

Maestro is YAML-based mobile E2E — simpler than Detox, works in CI without native compilation. Playwright is used for web E2E; Maestro covers mobile.

### Siri integration approach

SiriKit Intents require a native iOS extension. Expo handles this via Expo Modules API — a TypeScript + Swift bridge without ejecting to bare workflow. ~90% of the code is adapt/copy from existing `ios/Intents/`. Deferred to Phase 2 — Phase 1 gets mic input only.

---

## 2. Native Tooling Additions

_Extracted from: v0-web.md → "Tooling Already in the Devcontainer", Phase 0a Step 1, Phase 0b Steps 3b and 4_

### Dockerfile additions

Add to the Dockerfile after `npm install -g bun`:

```dockerfile
RUN npm install -g @expo/eas-cli
```

Note: `pnpm` is already part of the web devshop Dockerfile. EAS CLI is native-only.

### Firewall additions

Add to `init-firewall.sh` domain list:

```
"expo.dev" \
"api.expo.dev" \
```

These are required for `eas login`, `eas build`, and `eas update` commands run inside the devcontainer. GitHub Actions CI/CD runs on GitHub's servers and does not need the firewall updated for EAS — but initial setup and local EAS commands do.

### `.npmrc` hoisting patterns for Expo monorepo

_Extracted from: v0-web.md → Phase 0b Step 3b_

Create at repo root:

```
# Expo monorepo hoisting — required for Metro to resolve native packages.
# These patterns must be kept in sync with Expo's monorepo docs:
# https://docs.expo.dev/guides/monorepos/
# When upgrading Expo SDK, re-check the docs and update this list in the same commit.
public-hoist-pattern[]=*react*
public-hoist-pattern[]=*react-native*
public-hoist-pattern[]=*@react-native*
public-hoist-pattern[]=*@react-navigation*
public-hoist-pattern[]=*expo*
public-hoist-pattern[]=*@expo*
public-hoist-pattern[]=*babel*
public-hoist-pattern[]=*metro*
```

Without complete hoisting, Metro silently fails to resolve native packages. The error says "module not found" with no hint that it's a hoisting issue. Commit this before running any `pnpm install` for the mobile app.

**Important**: If the web devshop already has an `.npmrc`, append these patterns — do not replace existing content.

### Metro config for pnpm symlink resolution

_Extracted from: v0-web.md → Phase 0b Step 4_

Create `apps/mobile/metro.config.js` — Metro can't resolve pnpm symlinks by default, so workspace packages (`@lalista/core`, `@lalista/ui`) will be invisible to the bundler without this:

```js
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '../..');

const config = getDefaultConfig(projectRoot);

// Watch all packages in the monorepo
config.watchFolders = [workspaceRoot];

// Resolve modules from the workspace root first, then the project
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
];

module.exports = config;
```

This is required for any `@<project>/*` import to work in the mobile app.

### Mobile Jest `transformIgnorePatterns` workaround

_Extracted from: v0-web.md → Phase 0b Step 4 and Non-Negotiables_

Expo's Jest preset sets `transformIgnorePatterns` that skips all of `node_modules` except specific Expo packages. Workspace packages (`@<project>/*`) exporting raw TypeScript source will fail with `SyntaxError: Unexpected token 'export'`. The mobile Jest config must add all workspace packages to the `transformIgnorePatterns` exception list.

Update Jest config in `apps/mobile/` to add workspace packages to the exception list so Jest can transpile `@<project>/*` packages that export raw TypeScript source. Without this, every test importing from shared packages fails with `SyntaxError: Unexpected token 'export'`.

---

## 3. Known Footguns (Native)

_Extracted from: v0-web.md → Phase 0a Step 9 (`.devshop/CLAUDE.md` content) and Non-Negotiables_

### pnpm + Expo hoisting (Metro "module not found")

If Metro fails with "module not found" for a clearly installed package, check `.npmrc` hoisting patterns against Expo's current monorepo docs. When upgrading Expo SDK, re-check and update `.npmrc` in the same commit.

### Mobile Jest + shared TS packages (SyntaxError: Unexpected token 'export')

If mobile tests fail with `SyntaxError: Unexpected token 'export'` on workspace package imports, add workspace packages to `transformIgnorePatterns` exception list in mobile Jest config. The failure IS the enforcement — if mobile tests don't pass, this is the first thing to check.

---

## 4. Accounts & Secrets (Native additions)

_Extracted from: v0-web.md → "Accounts to Set Up Before Phase 0" and Phase 0b Prerequisites_

### Accounts

| Service             | Action                                                                                                                                           | Cost   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| **Expo**            | Create account at expo.dev                                                                                                                       | Free   |
| **Apple Developer** | Enroll at developer.apple.com — takes 1-2 days to process. Required for Sign in with Apple on both web and mobile, and for App Store submission. | $99/yr |

### Secrets — `.devcontainer/.env` additions

```
EXPO_TOKEN=<expo-access-token>
EXPO_PROJECT_ID=<expo-project-id>
```

- Expo: expo.dev → Account Settings → Access Tokens. Using `EXPO_TOKEN` instead of `eas login` means EAS auth survives container rebuilds — no re-login needed.
- `EXPO_PROJECT_ID` is the project ID from the Expo dashboard (expo.dev → your project → Project ID) — required for non-interactive `eas init --id`.

### Secrets — GitHub Secrets additions

- `EXPO_TOKEN` — expo.dev → Account Settings → Access Tokens (for EAS in CI)

---

## 5. Phase: Add Native to Devshop (Phase 0-native)

_Steps to add native capability to an existing web devshop project. Extracted from: v0-web.md → Phase 0a Steps 1-2 and Phase 0b Steps 3b, 4_

> **Prerequisite**: The web devshop (Phase 0a + 0b for web) must be complete and validated before starting this phase.

### Step 1: Add EAS CLI to Dockerfile

Add to the Dockerfile after the existing npm global installs:

```dockerfile
RUN npm install -g @expo/eas-cli
```

### Step 2: Add expo.dev domains to firewall

Add to `init-firewall.sh`:

```
"expo.dev" \
"api.expo.dev" \
```

Note: After editing the Dockerfile and firewall, the devcontainer must be rebuilt. **[HUMAN]** Rebuild the devcontainer (VS Code: "Dev Containers: Rebuild Container").

### Step 3: Create `.npmrc` with hoisting patterns

See Section 2 above for the full `.npmrc` content. If the web devshop already has an `.npmrc`, append the Expo hoisting patterns.

### Step 4: Scaffold `apps/mobile/`

_Extracted from: v0-web.md → Phase 0b Step 4_

```bash
cd /workspace
pnpm create expo-app apps/mobile --template blank-typescript
```

Then:

- Install Expo Router: `pnpm add expo-router --filter apps/mobile`
- Add `@<project>/core`: `pnpm add @<project>/core --filter apps/mobile`
- Add Sentry: `pnpm add @sentry/react-native --filter apps/mobile`
- Add PostHog: `pnpm add posthog-react-native --filter apps/mobile`
- Create `eas.json` with three profiles:
  ```json
  {
    "build": {
      "development": { "developmentClient": true, "distribution": "internal" },
      "preview": { "distribution": "internal" },
      "production": {}
    }
  }
  ```
  Profiles: `development` (Expo Go), `preview` (internal distribution/TestFlight), `production` (App Store).
- Run `eas init --id $EXPO_PROJECT_ID` to link to Expo project non-interactively (uses `EXPO_TOKEN` from `.devcontainer/.env` — no `eas login` needed; `EXPO_PROJECT_ID` is the project ID from expo.dev, added to `.devcontainer/.env` in Phase 0-native prerequisites)
- Add placeholder screen that uses `@<project>/ui` token (validates workspace linking). Mobile components use `StyleSheet.create` with values from `packages/ui/src/tokens.ts` — no Tailwind/NativeWind on mobile.
- **Create `apps/mobile/metro.config.js`** — see Section 2 above for full code block.
- **Update Jest config** — add workspace packages to `transformIgnorePatterns` exception list. See Section 2 above for details.
- When `pnpm create expo-app` generates any eslint config, **delete it** and replace with an equivalent extending the root:
  ```js
  // apps/mobile/eslint.config.mjs
  import rootConfig from '../../eslint.config.mjs';
  export default [...rootConfig];
  ```

### Step 5: Update `packages/ui` with mobile component variants

Shared UI components in `packages/ui` that target both platforms: export two variants or use `Platform.select` with token values, not Tailwind classes.

Example pattern for a component like `Button`:

- Web variant: uses Tailwind classes (`className="bg-terracotta"`)
- Mobile variant: uses `StyleSheet.create` with token values

See v0-web.md Phase 0b Step 2 for the initial `packages/ui` setup. The mobile step adds mobile variants to existing web components.

### Step 6: Add mobile Sentry SDK

Add `@sentry/react-native` in `apps/mobile`. Catches: uncaught exceptions, promise rejections, React error boundaries, native crashes. Configure source map upload in CI (`SENTRY_AUTH_TOKEN`) for readable stack traces.

### Step 7: Add mobile PostHog SDK

Add `posthog-react-native` in `apps/mobile`. Track key flows: item added, item bought, store routed, sign in, sign out. Feature flags work the same as web.

### Step 8: Env var naming (EXPO*PUBLIC* prefix)

Each framework requires a specific prefix for client-accessible vars. GitHub Secrets use the base name; each surface adds its own prefix:

| Secret (base name)        | Expo/React Native               |
| ------------------------- | ------------------------------- |
| `SUPABASE_URL`            | `EXPO_PUBLIC_SUPABASE_URL`      |
| `SUPABASE_ANON_KEY`       | `EXPO_PUBLIC_SUPABASE_ANON_KEY` |
| `SENTRY_DSN`              | `EXPO_PUBLIC_SENTRY_DSN`        |
| `NEXT_PUBLIC_POSTHOG_KEY` | `EXPO_PUBLIC_POSTHOG_KEY`       |

`packages/core` does **not** read env vars directly — it exports a typed `createClient(config: CoreConfig)` factory. Each app reads its own prefixed vars and passes them in.

### Step 9: Devcontainer tip — testing on iPhone

The devcontainer can't use LAN to reach your phone. To run the Expo dev server from inside the container and connect your iPhone to it:

```bash
cd apps/mobile
npx expo start --tunnel
```

This uses ngrok to create a public URL. Scan the QR code with the Expo Go app on your iPhone. Works from anywhere, no LAN required.

---

## 6. Phase 1 Native: Migrate lalista to iOS

_Extracted from: v0-web.md → Phase 1, mobile-specific parts. All web equivalents remain in v0-web.md._

> These steps parallel the web Phase 1 screens. See v0-web.md Phase 1 for the full context, web implementations, and shared `packages/core` work (1c) that both platforms depend on.

### 1b: Mobile font loading + mobile component variants

_Extracted from: v0-web.md → Phase 1b_

1. Mobile font loading: Expo Google Fonts package (`@expo-google-fonts/fraunces`, `@expo-google-fonts/plus-jakarta-sans`)
2. Create mobile component variants for all base components (`Button`, `Text`, `Card`, `Input`, `Divider`) using `StyleSheet.create` with token values from `packages/ui/src/tokens.ts`
3. Shared components export platform-specific variants or use `Platform.select`
4. Tests: snapshot tests for each component in light + dark mode (Jest snapshot)

### 1d: Mobile auth

_Extracted from: v0-web.md → Phase 1d_

**Prerequisite**: Apple Developer account must be approved before implementing Apple sign-in.

1. **Mobile**: Supabase Auth + `@invertase/react-native-apple-authentication`
2. Persist session via Supabase's built-in session storage, auto-refresh, redirect to list on auth
3. Sign-out flow
4. Household onboarding flow (same logic as web — see v0-web.md 1d for full spec)
5. Tests: unit tests for auth state transitions + household check logic

### 1e: Mobile screen implementations

_Extracted from: v0-web.md → Phase 1e. These parallel the web screens — same functionality, mobile-native UI._

For each screen: implement → write tests → run → fix → mark done. Do not move to next screen until tests pass.

1. **Sign-in screen**: email/password form + Apple sign-in button
2. **Household onboarding screen**: create household (name input) or "ask a family member to add you" placeholder — shown after sign-in if user has no household
3. **List view**: items grouped by store, item rows with buy button (calls `mark_item_bought` RPC — not a direct table write), loading/empty/error states. Subscribes to Realtime channel for live updates.
4. **Add item flow**: text input + submit + **disambiguation sheet** — when the edge function returns candidates instead of a resolved item, show a bottom sheet listing the candidates for the user to pick from. Reference: `ios-archive/ios/Sources/Views/List/DisambiguationSheet.swift`. This is a first-class flow, not an edge case — it fires whenever NLP confidence is below threshold.
5. **Offline strategy**: decision made during web Phase 1 applies to mobile as well (see v0-web.md 1e item 5 for the options: full offline, no offline, or read-only offline)
6. **Item detail**: item name, store, brand, edit, delete
7. **Settings screen**: sign out, household name
8. **Sync error banner**: shown when Supabase is unreachable

Design reference: `DESIGN.md` — all colors, fonts, spacing must match. The `/design-review` skill must explicitly check for visual divergence between web and mobile — any difference that can't be explained by intentional platform divergence is a bug.

Reference for layout/behavior: `ios-archive/ios/Sources/Views/` (Swift code shows what each screen should do)

### 1g: Mobile testing

_Extracted from: v0-web.md → Phase 1g_

1. `apps/mobile`: Jest component tests for all screens
2. Maestro E2E flow for happy path: sign in → add item → disambiguation (if triggered) → see in list → mark bought
3. All tests pass: `pnpm turbo run test`

---

## 7. Phase 2: Advanced Native Features

_Extracted from: v0-web.md → Phase 2. This section is almost entirely native-specific._

### 2a: Mobile maturity → App Store

_Extracted from: v0-web.md → Phase 2a_

1. Apple Developer Program enrollment happens at Phase 1 kickoff (see Phase 0b prerequisites) — by Phase 2 the account is already active
2. Configure EAS Build profiles: `development` (dev client), `preview` (TestFlight internal), `production` (App Store)
3. Add `eas-update.yml` to CI — auto OTA on every main merge, now that a build channel exists
4. Add `eas-build.yml` GitHub Actions workflow — triggers on `v*` tags → full native build → EAS Submit → TestFlight
5. **[HUMAN]** App Store Connect: create app entry, screenshots, description, keywords, privacy policy URL
6. Write a minimal privacy policy page (required for App Store): data collected, deletion process, contact
7. Test the full release cycle: tag `v0.1.0` → EAS Build → EAS Submit → TestFlight → install on device

### 2b: Siri integration

_Extracted from: v0-web.md → Phase 2b_

1. Study the existing `ios-archive/ios/Intents/` Swift code — this is the reference implementation
2. Write `expo-siri-intents` Expo Module using Expo Modules API:
   - TypeScript interface: `addGroceryItem(name: string): Promise<void>`
   - Swift implementation: ports the Intents extension from `ios-archive/`
   - Config plugin: registers the Intents extension in the Xcode project
3. Wire up Siri intent handler in Expo Router
4. Test exclusively on physical device (Siri does not work in simulator)
5. Add Siri usage description to App Store listing

### 2c: Developer tooling improvements (web + native shared)

_Extracted from: v0-web.md → Phase 2c_

> **Note**: Items 1 and 2 below are NOT native-specific. They should be evaluated for inclusion in the web devshop plan if not already there.

1. **Changesets**: `pnpm add -D -w @changesets/cli` + `.changeset/config.json` — automated changelogs in PRs
2. **Dependabot**: create `.github/dependabot.yml` — weekly PRs for npm security updates
3. **E2E in CI**: add Playwright + Maestro to `ci.yml` (currently run locally only)
4. **Visual regression**: add Playwright screenshot comparison for key screens
   - Store baseline screenshots in `tests/screenshots/`
   - CI step: compare current vs baseline, fail if diff > threshold

### 2d: Mac app

_Extracted from: v0-web.md → Phase 2d_

1. Expo SDK 52 supports Mac Catalyst — same codebase, new build target
2. Add `mac` profile to `eas.json`
3. Test with `npx expo run:macos` locally
4. EAS Submit to Mac App Store

### Android follow-on

Android follows the same pattern (Expo → Google Play) — defer until Mac is working and validated.

---

## 8. Mobile E2E in CI — Options (Unresolved)

_Extracted from: v0-web.md → Non-Negotiables section_

**Default: local-only pre-ship gate.** Mobile E2E tests exist and run on the host Mac (not in the devcontainer — the iOS simulator requires macOS) before `/ship`, but are not in CI. CI runs unit + component tests for mobile; E2E is a local pre-ship gate.

Before `/ship`: open a host terminal, `cd` to the repo, run `maestro test flows/`. Document this in project README.

The new-project checklist requires writing a one-line rationale for the chosen approach in the project's `CLAUDE.md`.

### Future options when revisiting:

1. **Maestro Cloud** — real devices, free tier available (terms may change). Zero local infra.
2. **macOS CI runner (GitHub Actions)** — full iOS simulator in CI. ~$0.08/min, adds up for frequent PRs.
3. **Android emulator only** — free on Linux CI runners. No iOS coverage; behavior differences exist.
4. **Self-hosted macOS runner** — register your Mac as a CI runner. Real simulator, real CI. Requires Mac always on.
5. **SSH bridge from container** — container triggers `maestro test` on host via `ssh host.docker.internal`.
6. **File watcher bridge** — container writes trigger to shared volume, macOS launchd agent runs maestro.
7. **Paid macOS CI runners** (e.g. CircleCI, Bitrise) — revisit when budget allows.

**Decision deferred** until native devshop is being built.

---

## 9. CI/CD Additions for Native

_Extracted from: v0-web.md → "CI/CD Pipeline" and Phase 2a_

### `eas-update.yml` — OTA updates

Triggers on merge to main:

```
EAS Update → pushes JS bundle OTA to all app users
(no App Store review required for JS-only changes)
```

Note: deferred to Phase 2 — requires a prior EAS Build to establish a channel first. Creating it before a build channel exists causes every push to `main` to produce a failing CI job.

### `eas-build.yml` — full native build

Triggers on git tag `v*`:

```
EAS Build → full native iOS build
EAS Submit → TestFlight → App Store review
```

### Additional GitHub Secrets for native

- `EXPO_TOKEN` — expo.dev → Account Settings → Access Tokens (for EAS in CI)

This is in addition to the web devshop secrets (SUPABASE_URL, SUPABASE_ANON_KEY, etc.). See v0-web.md "Required GitHub Secrets" for the full list.

---

## 10. Native Checkpoints

_Extracted from: v0-web.md → Phase 0b, Phase 1, and Phase 2 checkpoints (mobile-specific items only)_

### Phase 0-native Checkpoint

- [ ] `eas build --profile development --platform ios` succeeds (placeholder app)
- [ ] Mobile placeholder screen imports and renders a `@<project>/ui` token successfully
- [ ] Mobile Jest tests pass (including workspace package imports)
- [ ] Metro bundler resolves all `@<project>/*` workspace packages

### Phase 1 Checkpoint (mobile-specific)

- [ ] iOS app on device via Expo Go + tunnel: sign in → create household (new user) → add item → disambiguation sheet appears when NLP is ambiguous → see item in list → mark bought
- [ ] Mobile app: list updates in real time when a second session adds an item (or offline strategy is documented)
- [ ] Mobile app: dark mode works
- [ ] Mobile app: error states handled gracefully (network down, Supabase unreachable)
- [ ] Mobile Jest component tests all green
- [ ] Sentry catches an error from mobile app
- [ ] PostHog receives events from mobile app

### Phase 2 Checkpoint

- [ ] App live on App Store via TestFlight — install, sign in, add item, works
- [ ] OTA update delivered after a main merge — app updates without reinstall
- [ ] Siri: "Hey Siri, add milk to my list" → item appears in lalista
- [ ] `v0.1.0` tag → full App Store submission completes without errors
- [ ] Mac app builds and runs

---

## 11. Stack Summary (Native additions)

_Extracted from: v0-web.md → "Stack Summary" table (native rows only)_

| Layer              | Tool                                                | Why                                         |
| ------------------ | --------------------------------------------------- | ------------------------------------------- |
| Mobile app         | Expo SDK 52 + React Native                          | Cloud builds, OTA updates, Expo Router      |
| Shared UI (mobile) | `packages/ui` + `StyleSheet.create` + shared tokens | Unified via `tokens.ts`, no NativeWind      |
| Mobile builds      | EAS Build (free tier)                               | Cloud iOS builds, no Xcode in CI            |
| Mobile OTA         | EAS Update                                          | JS-only fixes bypass App Store review       |
| App Store          | EAS Submit                                          | Automates TestFlight + App Store submission |
| Errors (mobile)    | `@sentry/react-native`                              | Crash reports including native crashes      |
| Analytics (mobile) | `posthog-react-native`                              | Same events + feature flags as web          |
| Mobile unit tests  | Jest (Expo preset)                                  | Expo ships Jest config                      |
| Mobile E2E         | Maestro                                             | YAML-based, simpler than Detox              |

**Phase 2 only** (native): EAS Submit automation, Siri integration (Expo Modules API), Mac app (Expo Catalyst).

---

## Repository Structure (Native additions)

_For reference — these are the native-specific files/directories that get added to the web devshop structure._

```
<project>/
├── apps/
│   └── mobile/                     ← Expo SDK 52 (React Native)
│       ├── app/                    ← Expo Router screens
│       ├── components/             ← screen-level components (StyleSheet.create + tokens)
│       ├── metro.config.js         ← pnpm symlink resolution for monorepo
│       ├── eas.json                ← EAS build profiles
│       └── package.json
├── .npmrc                          ← updated: add Expo hoisting patterns
├── .github/
│   └── workflows/
│       ├── eas-update.yml          ← EAS OTA update (on main merge) — Phase 2
│       └── eas-build.yml           ← full native build (on v* tag) — Phase 2
└── .devcontainer/
    ├── Dockerfile                  ← updated: add EAS CLI
    └── init-firewall.sh            ← updated: add expo.dev + api.expo.dev
```
