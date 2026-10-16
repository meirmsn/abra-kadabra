# Tests

The project's tests live here. CI's fast tier runs the unit tests, and its slow tier the end-to-end
tests.

Each test that proves an acceptance item of a spec in `specs/` has the item's name in its own name
or description, so the spec check (`scripts/spec-check.py`, run by `scripts/check-fast.sh`) finds
it. An item that no test names fails CI, unless the spec marks it "verified by review".
