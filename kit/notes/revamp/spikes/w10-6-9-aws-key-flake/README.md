# W10.6.12 fake secrets gitleaks misses (F-NEW-50)

`fast` failed once on a PR on 2026-10-13: `FAIL: secret added then removed in the change fails:
expected fail, got exit 0`. `fake_aws_key` (`tests/lib.sh`) drew 16 characters with repeats, and now
and then a key repeated so much that its entropy fell below the `aws-access-token` rule's 3, so
gitleaks 8.30.1 dropped it. Same class as F-NEW-45 (LOG #56), whose fix covered other generators.
This folder measures every fake that gitleaks scans in the tests, before and after. 2026-10-13, LOG #57.

`measure.sh <kind> <n>` writes `n` values from one generator, one per file, scans them with the
pinned gitleaks and this repo's `.gitleaks.toml`, and counts the files without a finding under the
expected rule.

## Result

| Generator (gitleaks 8.30.1)                                     | Rule's entropy | Missed          |
| --------------------------------------------------------------- | -------------- | --------------- |
| AWS key, old: `AKIA` + 16 × `rand 'A-Z2-7' 1`, repeats allowed  | 3              | 6 / 30,000; 5 / 30,000; 2 / 18,000 |
| AWS key, new: `AKIA` + 16 distinct of `A-Z2-7`                  | 3              | **0 / 30,000**  |
| Generic API key, old: 16 × (`a-z`, `0-9`), repeats allowed      | 3.5            | not run at scale ¹ |
| Generic API key, new: 16 distinct letters, no digit > 2 times   | 3.5            | **0 / 30,000**  |
| GitHub token: `ghp_` + 36 × `A-Za-z0-9`                         | 3              | 0 / 30,000      |
| Slack bot token                                                 | none           | 0 / 30,000      |
| Private key                                                     | none           | 0 / 30,000      |

¹ Its values take 32 `rand` calls each; 30,000 would take about 100 minutes and expect 0.6 misses.
Shown instead: by the entropy formula, 4 in 200,000 old values score below 3.5 (lowest 3.445); and
gitleaks 8.30.1 missed all 6 hand-picked values scoring 3.36–3.49 and caught all 6 scoring 3.50–3.63.

- **Cause, not chance:** the four AWS misses checked by hand (`AKIAK7AGA6AR7B7KDSKA`,
  `AKIAIPICJ2KAIJJ3P2IN`, `AKIA4KZKPEP4XIKKAAE7`, `AKIAK4SJSH7KKSKJSK2K`) score 2.74–2.97 over the
  whole 20-character match; a control key scoring 4.02 is caught.
- **Rate:** by the entropy formula, 199 in 1,000,000 old AWS keys score below 3 (about 1 in 5,000).
  The tests draw about 7 keys a run (`secret-scan.test.sh` 4, `git-hooks.test.sh` 2,
  `gitleaks.test.sh` 1), so about 1 `fast` run in 700 failed. The 2 in 3,000 first reported was a
  high draw.
- **The fix is a bound, not a lower rate.** 16 distinct characters give an AWS key at least 3.88
  (`AKIA` + `A`, `K`, `I` + 13 others is the worst case), and a key can't end in `EXAMPLE`, which
  gitleaks always ignores, because that needs two `E`s. 16 distinct letters and digits used at most
  twice give a generic value at least 4.5. Letters and digits still alternate, so no stopword fits
  (F-NEW-45).
- **The GitHub token** is drawn the old way but has room: by the formula, 0 of 200,000 below 3,
  lowest 3.92. The Slack and private-key rules have no entropy threshold. The other `rand` callers
  (`tests/bootstrap.test.sh`) are never scanned by gitleaks.
- **Kept as a test:** `tests/gitleaks.test.sh` step 0 draws 50 of each fake and fails on a repeated
  AWS character, a repeated generic letter or a generic digit used three times. With the old
  generators it failed at once: an AWS key with a repeated `X` (not quoted here: it
  scores above 3, so the repo's own secret scan would flag it) and a generic value with a repeated `v`.
