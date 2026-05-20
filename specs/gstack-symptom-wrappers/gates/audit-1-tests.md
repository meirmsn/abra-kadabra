### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/gstack-symptom-wrappers.bats:200-212`
**What**: `capture-screenshot.sh` documents 4 exit codes (`0 ok, 2 usage error, 3 browse failure, 4 cp failure`) but the bats suite never exercises **exit 4** (cp failure). Tests cover 0 (tests 14/15/18), 2 (test 9), and 3 in two flavors (16: browse non-zero; 17: empty file), but the `cp` failure branch at script line 87 — `if ! cp "$STAGE_PATH" "$ABS_FINAL"; then ... exit 4; fi` — is untested.
**Why**: a regression that swaps `cp` for `mv` (a tempting "simpler" refactor that the script's existing comment explicitly warns against) would still pass all 20 tests, even though it would change the exit-4 path's behavior on failure (mv on a cross-filesystem move with permission denial on dest exits differently). More concretely, an upstream `cp` argument-order swap or `--no-clobber` addition could turn exit-4 into a silent success or a different exit code, and the suite would not catch it.
**Fix**: add one bats test that engineers a deterministic cp failure — make the destination dir read-only (`chmod 0500`) before invoking the wrapper, assert `status -eq 4` and `output` contains `"cp ... failed"`. Example:

```bash
@test "Sub-B: wrapper exits 4 when cp to final path fails" {
  setup_mock_bin
  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "screenshot" ] && [ -n "$2" ] && { printf 'PNG\n' > "$2"; exit 0; }
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"

  SANDBOX="$BATS_TEST_TMPDIR/readonly"
  mkdir -p "$SANDBOX"
  chmod 0500 "$SANDBOX"  # read+execute only — cp into here fails

  run bash "$CAPTURE_SCRIPT" "$SANDBOX/shot.png"
  chmod 0700 "$SANDBOX"  # restore for cleanup
  [ "$status" -eq 4 ]
  [[ "$output" == *"cp"*"failed"* ]]
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/gstack-symptom-wrappers.bats:123-127`
**What**: the fallback `browse` binary discovery branch (`BROWSE_BIN=/devshop/.claude/skills/gstack/browse/browse` when `command -v browse` fails) is verified only **structurally** (test 13 greps for the literal path string in the script). The behavioral branch — what happens when `browse` is NOT on PATH AND the fallback path is also absent — is never exercised. The "binary not found" error message at script lines 57-60 (`error: 'browse' binary not found on PATH or at ...`, `exit 3`) is unreachable by the current suite.
**Why**: this is the primary user-facing error for a half-installed gstack (the most common installation failure mode for the very symptom this wrapper exists to work around). A future refactor that, say, drops the fallback path or changes the error message would not be caught by the structural grep alone — and the structural grep is satisfied even by a comment containing the literal string.
**Fix**: add one behavioral test that scrubs PATH and points the fallback at a missing file, asserting exit 3 + the binary-not-found message:

```bash
@test "Sub-B: wrapper exits 3 with a clear message when browse binary is missing entirely" {
  # Empty PATH so `command -v browse` fails; fallback path is absent in this sandbox.
  run env -i PATH="$BATS_TEST_TMPDIR/empty" HOME="$HOME" bash "$CAPTURE_SCRIPT" "$BATS_TEST_TMPDIR/x.png"
  [ "$status" -eq 3 ]
  [[ "$output" == *"'browse' binary not found"* ]]
}
```

### [domain: tests] [section: C] [severity: low]

**File**: n/a
**What**: no `Tests-Coverage-Bypass:` trailers in the commit range (one commit: `2f08711`); harvest returns zero rows.
**Why**: section C is forward-compatible per the skill's spec — legitimate zero-row outcome, noted for completeness.
**Fix**: none.
