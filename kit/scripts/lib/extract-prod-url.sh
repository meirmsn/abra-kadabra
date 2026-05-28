#!/usr/bin/env bash
# kit/scripts/lib/extract-prod-url.sh
#
# Tiny, sourceable helper exposing extract_prod_url() for `/ak-go-live`:
#   - Step 1.5 (production health probe)
#   - Step 1.5 Mode A in-session escape hatch
#   - Step 3 reuses Step 1.5's result, so no third call site.
#
# Single source of truth — the two call sites previously carried identical
# inline `sed` pipelines, so a parse bug broke BOTH. home-os PR #39's
# /ak-go-live run hit exactly this: home-os's CLAUDE.md writes the URL
# mid-sentence —
#   Production URL: `https://home-os-nu-two.vercel.app`. Full deploy config: ...
# The old `sed 's/^[^:]*:[[:space:]]*//'` took the rest of the line, then
# the global space-strip glued the host to the trailing prose
# (`home-os-nu-two.vercel.app.Fulldeployconfig...`), failing DNS validation
# and silently skipping the probe.
#
# This file does NOT execute anything when sourced — it only defines the
# `extract_prod_url` function. Safe to `source` without `set -euo pipefail`
# interactions.

# extract_prod_url <claude-md-path>
#
# Echo the bare production hostname (no scheme, no path, no trailing dot)
# parsed from the first `Production URL` line of <claude-md-path>, or echo
# nothing (empty) when no valid host is found.
#
# Tolerates the URL appearing anywhere on the line, in any of the shapes
# seen in the wild:
#   Production URL: https://app.vercel.app
#   Production URL: `https://app.vercel.app`. More prose here.
#   Production URL: app.vercel.app                  (scheme-less)
#   - **Production URL:** https://app.vercel.app/path  (path stripped)
#
# Returns the host only; the caller is responsible for re-adding `https://`
# and for DNS-label validation (the validation regex stays at the call site
# so the "configured but malformed" vs "not configured" messaging is local).
#
# Exit code: 0 always — "no host found" is a valid outcome (caller treats
# empty as "not configured" and skips the probe).
extract_prod_url() {
  local claude_md="$1"
  [ -z "$claude_md" ] || [ ! -f "$claude_md" ] && return 0

  local raw_line host
  # Anchor on the canonical label at line start (allowing Markdown bullet /
  # blockquote / bold wrappers) so a prose line that merely mentions a
  # "production url" earlier in the file can't win over the real
  # `Production URL:` line. `grep -i 'production.*url'` (unanchored) matched
  # those words anywhere, picking the wrong line → silent skip / wrong host.
  raw_line=$(grep -iE '^[[:space:]]*[-*+>_ ]*production url[*_ ]*:' "$claude_md" 2>/dev/null | head -1)
  [ -z "$raw_line" ] && return 0

  # Preferred: grab the first explicit http(s) URL token. The character
  # class stops at the first non-URL char (backtick, period+space, closing
  # paren, quote), so trailing prose and Markdown punctuation are excluded.
  # A path is dropped because `/` is not in the class. A trailing dot
  # (URL ending a sentence: `...app.`) is stripped after the fact.
  host=$(printf '%s' "$raw_line" \
    | grep -oiE 'https?://[a-zA-Z0-9.-]+' | head -1 \
    | sed -E 's|^[Hh][Tt][Tt][Pp][Ss]?://||; s/[.]+$//')

  # Fallback for scheme-less configs (`Production URL: app.vercel.app`):
  # strip the label + Markdown wrappers, then take the first hostname-shaped
  # token.
  if [ -z "$host" ]; then
    host=$(printf '%s' "$raw_line" \
      | sed -E 's/^[^:]*:[[:space:]]*//; s/[`<>"'\'']+//g' \
      | grep -oE '[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+' \
      | head -1)
  fi

  printf '%s' "$host"
}
