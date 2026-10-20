# Tests

The project's tests live here. CI's fast tier runs the unit tests, and its slow tier the end-to-end
tests.

Each test that proves an acceptance item of a spec in `specs/` names the item as the project
contract's rule says (`scripts/contract-check.py --list`, under `scripts/spec-check.py`): `AC-<n>` in
its own name or description, with the spec's file name before it (`<spec> AC-<n>`) once this repo
has more than one spec. The spec check (`scripts/spec-check.py`, run by `scripts/check-fast.sh`)
finds the `AC-<n>`; an item that no test names fails CI, unless the spec marks it "verified by
review".
