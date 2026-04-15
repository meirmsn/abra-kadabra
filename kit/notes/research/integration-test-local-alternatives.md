# Local Integration Test Alternatives

v0 uses Docker-in-Docker inside the devcontainer for `supabase start`. This requires
16GB+ RAM (3 layers of virtualization on macOS: macOS → Docker Desktop VM →
devcontainer → DinD → Supabase containers). When hardware is constrained, integration
tests run only in CI (10-15 min feedback loop).

These alternatives reduce the feedback loop for integration tests locally.

## Option A: Host Supabase, connect from devcontainer

Run `supabase start` on macOS directly (Docker Desktop, no DinD). The devcontainer
connects via host networking (`host.docker.internal:54321`).

**Pros**: No DinD overhead. Works on 8-16GB machines. Fast (Supabase runs natively
on Docker Desktop). Same local Postgres behavior as CI.

**Cons**: Breaks "everything inside the container" isolation. Supabase runs outside
the firewall boundary (though local Postgres on the host LAN is already allowed).
Adds a host-side setup step. Two places to manage Supabase CLI version.

**Implementation**: Add a `SUPABASE_HOST` env var to devcontainer config (default:
`localhost` for DinD, override to `host.docker.internal` for host mode). Integration
test config reads this. Document both workflows in `.devshop/GUIDE.md`.

## Option B: Dedicated remote dev Supabase instance

A second free-tier Supabase project (e.g., `lalista-dev-test`) used exclusively for
integration tests. Reset via `supabase db reset` before each test run.

**Pros**: Zero local resource overhead. Identical to production Supabase behavior
(hosted, not local emulator).

**Cons**: Violates "never hit shared remote from tests." Slower than local (~50-200ms
per query vs <1ms). Free tier limits (2 projects). Test pollution risk if reset fails.
Requires network access to Supabase from devcontainer.

**Implementation**: Add test project credentials to `.devcontainer/.env`. Integration
test runner resets DB before suite. CI continues using its own `supabase start`.

## Option C: Optimize CI-only workflow

Keep DinD as the only local integration test path. Accept that constrained machines
use CI for integration tests. Optimize the CI feedback loop instead.

**Pros**: No architecture changes. Clean isolation model preserved.

**Cons**: 10-15 min feedback loop for integration test failures. Multiple push cycles
for data-layer bugs.

**Optimizations**:

- `gh run watch` integration for immediate CI failure notification
- Script to run just the slow CI job locally via `act` (GitHub Actions local runner)
- Split integration tests by domain so CI can report which area failed faster

## Current decision (2026-04-05)

Starting with DinD (v0). If DinD proves too heavy on the development machine,
Option A (host Supabase) is the first fallback — simplest change, best feedback loop.
Tracked in `.devshop/ROADMAP.md` v1.
