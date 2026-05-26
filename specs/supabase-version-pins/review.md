# Review — supabase-version-pins

## Audit 1: manual (2026-05-26)

<!-- audited-at: 19c4cc45a7642772ba4329f50aff7a34a60597f1 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=2

### Docs findings

- [medium] (commit body of `19c4cc4`) — Missing `**Existing projects:**` migration block in commit body. The commit touches propagation-relevant `[locked]` surfaces (Dockerfiles, compose.yml, checksums.sha256, devcontainer.json). Per conventions.md § Existing-Project Migration Block, the block is required even when auto-sync handles propagation (the "no migration needed" variant). Fix: add the block to the squash message.

### Tests findings

- [low] template/.devcontainer/{compose.yml, supabase-runner/Dockerfile} — No structural test asserts `SUPABASE_CLI_VERSION` default stays in sync across the three sites (compose.yml workspace arg, compose.yml runner arg, supabase-runner/Dockerfile ARG default). Version drift is explicitly called out in the runner Dockerfile comment.
- [low] .devcontainer/Dockerfile + template/.devcontainer/{Dockerfile, supabase-runner/Dockerfile} — No structural test asserts all three Dockerfiles use the self-verifying checksum pattern (fetch `supabase_checksums.txt` + `sha256sum -c`). A future edit could accidentally revert to the old pattern.

### Bypass trailer audit

- (none)
