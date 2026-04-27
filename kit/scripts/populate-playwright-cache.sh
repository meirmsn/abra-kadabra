#!/usr/bin/env bash
# What: Populate ~/.cache/ms-playwright with stub directories that point at
#       the apt-installed Chromium binary, so Playwright's launch path stops
#       complaining about a missing browser cache. Idempotent.
# Why:  Devcontainers since 2026-04-23 apt-install /usr/bin/chromium and set
#       PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH, but Playwright's launch path
#       checks the cache dir BEFORE honoring the env-var override — so an
#       empty cache produces "Please run `npx playwright install`" even when
#       Chromium is system-installed. The CDN download is blocked by the
#       devcontainer firewall by design (smaller blast radius), so we stub
#       the cache instead.
# Does NOT: install Chromium, install Playwright, set the env var.

set -euo pipefail

CHROMIUM_PATH="${PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH:-/usr/bin/chromium}"

if [ ! -x "$CHROMIUM_PATH" ]; then
  echo "error: Chromium not found at $CHROMIUM_PATH" >&2
  echo "       (set PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH or apt-get install chromium)" >&2
  exit 2
fi

# Discover required Chromium revisions from each playwright-core's browsers.json.
# A project may have multiple playwright-core installs (workspace + nested + gstack).
# Stub all of them so whichever one is invoked at launch finds its expected paths.
TARGET_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DEVSHOP="${DEVSHOP:-/devshop}"
CACHE_DIR="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
mkdir -p "$CACHE_DIR"

revisions=()
while IFS= read -r browsers_json; do
  rev=$(grep -A1 '"name": "chromium"$\|"name": "chromium",' "$browsers_json" 2>/dev/null \
        | grep '"revision"' | head -1 | sed -E 's/.*"revision": *"([0-9]+)".*/\1/')
  [ -n "$rev" ] && revisions+=("$rev")
done < <(find "$TARGET_ROOT" "$DEVSHOP/.claude/skills/gstack" \
              -path '*/playwright-core/browsers.json' 2>/dev/null | sort -u)

# Dedupe.
unique_revs=$(printf '%s\n' "${revisions[@]}" | sort -u)

if [ -z "$unique_revs" ]; then
  echo "warn: no playwright-core browsers.json found under $TARGET_ROOT or $DEVSHOP" >&2
  echo "      (cache stub skipped; install playwright first if a browse skill needs it)" >&2
  exit 0
fi

for rev in $unique_revs; do
  for variant in "chromium-$rev" "chromium_headless_shell-$rev"; do
    dest="$CACHE_DIR/$variant/chrome-linux"
    mkdir -p "$dest"
    if [[ "$variant" == "chromium-$rev" ]]; then
      ln -sf "$CHROMIUM_PATH" "$dest/chrome"
    else
      ln -sf "$CHROMIUM_PATH" "$dest/headless_shell"
    fi
  done
  echo "ok: stubbed chromium-$rev + chromium_headless_shell-$rev → $CHROMIUM_PATH"
done
