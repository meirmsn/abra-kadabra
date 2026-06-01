findings: high=0 medium=0 low=3

### [domain: docs] [section: A] [severity: low]

**File**: kit/docs/guide/architecture.md:101
**What**: The Hybrid-lifecycle heading label still reads "chown-on-every-start (firewall-extra-domains)" while the same paragraph's body now (correctly) says the re-lock is ownership-conditional ("the chown/chmod runs only when the `stat -c '%U:%G %a'` tuple has drifted").
**Why**: Mild internal label/body drift inside a touched doc — a reader scanning headings sees "every-start" and the body qualifies it. Not a contradiction (the chown is still attempted every start, just short-circuited on no drift), so low, not medium.
**Fix**: Optionally rename the parenthetical label to "conditional-relock-on-start" to match the body; or leave as the historical lifecycle name with the body as authority.

### [domain: docs] [section: C] [severity: low]

**File**: kit/docs/FAQ.md:25
**What**: Summary bullet "root-owned copies refreshed every container start" carries the pre-change unconditional phrasing; the content-conditional no-op nuance is now in architecture.md but not reflected in this glanceable FAQ summary. (Carried forward from Audit 1 [low]; 8f557b2 did not touch FAQ.md.)
**Why**: FAQ is intentionally high-level and the claim is still semantically true (a [locked] file IS kept current every boot; only the unchanged-file case is now a filesystem no-op). Softening, not falsehood → low.
**Fix**: Optional one-clause parenthetical "(content-conditionally — an unchanged file is a no-op)" for cross-doc consistency.

### [domain: docs] [section: C] [severity: low]

**File**: kit/docs/guide/security.md:39 / kit/docs/guide/architecture.md:176
**What**: Both say [locked] files are "refreshed from template by init-devshop.sh on every container start" without the content-conditional caveat. (Carried forward from Audit 1 [low]; unchanged in range.)
**Why**: Both describe the refresh direction/semantics (template→project), which remain true — a drifted file still refreshes. The only changed nuance is that an unchanged file is now a no-op. Strictly still-accurate; low / accepted-as-is is defensible. architecture.md:176 in particular is making a sync-exclusion point where the conditionality is not load-bearing.
**Fix**: Optional one-clause parenthetical ("when content differs") on each to remove apparent tension with the new architecture.md table row.

### Resolved-since-Audit-1 (not findings — verified fixed at HEAD)

- [was medium, Audit 1] kit/manifest.txt:10 legend now reads "refreshes content only when it differs from the template source (cmp -s) and re-locks owner/mode only on drift, so a quiet boot is a no-op" — the canonical legend now tracks the behavior. Fixed in 8f557b2. VERIFIED at HEAD.
- architecture.md § File lifecycle table row + Hybrid-lifecycle paragraph correctly track the code (content-conditional refresh + tuple-drift re-lock). Confirmed at HEAD.

### Named-mechanism empirical verification

- `cmp -s` exit codes confirmed under the live shell: missing-dst exits 2, differing exits 1, identical exits 0 — so `! cmp -s` correctly takes the refresh branch on missing-or-differ and skips on match. The doc/inline-comment claims ("dst missing — cmp -s exits 2") are accurate.
- `stat -c '%U:%G %a'` confirmed to emit the `owner:group mode` tuple form (`node:node 644`) the docs and guards reference.

### Bypass trailer audit

- No Docs-Coverage-Bypass trailers in range.

Note on coverage: source change to kit/scripts/init-devshop.sh + kit/manifest.txt is matched by staged kit/docs/guide/architecture.md edits (satisfies the devshop coverage rubric for both surfaces). No Existing-Projects migration block appears in the commit bodies, but init-devshop.sh is itself [locked] and refreshes on rebuild — the canonical "no project-side migration needed" case; the BUILD-LOG records the closure. Not flagged (devshop-self bootstrap script; advisory at most).
