### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/manifest-lifecycle.bats`
**What**: The PR adds `.devcontainer/supabase-runner [locked-dir]` to `kit/manifest.txt` but no new test directly asserts that this `[locked-dir]` entry appears in `manifest_paths_by locked-dir`. The new regression test (lines 254-270) only checks the four `[locked]` leaves, not the sticky-bit dir.
**Why**: A future commit could silently drop the `[locked-dir]` entry (or downgrade it to `[locked]`), and the lock loop in `init-devshop.sh` would no longer create the `chmod 1755` sticky-bit dir — node could then delete locked leaves inside it (the exact failure mode `[locked-dir]` exists to prevent). The existing Test 8 (line 233) verifies `init-devshop.sh` calls `manifest_paths_by locked-dir`, but nothing pins the manifest content.
**Fix**: Add one line to the existing regression test (or a sibling test) that asserts `.devcontainer/supabase-runner` appears in `manifest_paths_by locked-dir`:

```bash
@test "regression: .devcontainer/supabase-runner is [locked-dir] in manifest" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    manifest_paths_by locked-dir
  "
  assert_success
  assert_line ".devcontainer/supabase-runner"
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/manifest-lifecycle.bats`
**What**: The PR's diff comment on `kit/scripts/init-devshop.sh` (lines 126-128) explicitly calls out that "Skips entries whose template source is absent" is load-bearing for host-supabase / skip projects, but no test asserts that `init-devshop.sh` contains the `[ -f "$src" ]` guard. (The guard pre-existed this PR, but the new compose-isolation `[locked]` entries make it newly load-bearing — without the guard, the install loop would fail on host-supabase / skip projects where `template/.devcontainer/compose.yml` etc. don't exist.)
**Why**: A future refactor could remove or invert the `[ -f "$src" ]` guard and the regression would only surface when a host-supabase / skip project rebuilds its container — a slow, scenario-specific failure mode. A static grep guard catches it at pre-push time.
**Fix**: Extend the existing "init-devshop.sh refreshes [locked] content via mode-deriving install" test (lines 237-252) with one additional assertion:

```bash
run grep -qE 'if \[ -f "\$src" \]; then' "$script"
assert_success
```

This pins the absent-source skip pattern that protects host-supabase / skip projects from install failure.
