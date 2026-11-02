#!/usr/bin/env bash
# run.sh <label>: build the spike app (app/, after `npm install` and a copy of shadcn/ui's button,
# see README.md), serve it on 127.0.0.1:4311, run the devshop's render check on it, stop the server.
# As run on 2026-11-02 from a scratch copy of app/, with the render check's path pointed at this repo.
here=$(cd "$(dirname "$0")" && pwd)
check="$here/../../../../../runtime/templates/ui/render-check.mjs"
cd "$here/app" || exit 2
export NEXT_TELEMETRY_DISABLED=1
timeout 300 npx next build >>../build.log 2>&1 || { echo "BUILD FAILED"; tail -20 ../build.log; exit 2; }
setsid npx next start -H 127.0.0.1 -p 4311 >>../start.log 2>&1 &
pid=$!
for _ in $(seq 1 30); do curl -sf -o /dev/null http://127.0.0.1:4311/ && break; sleep 1; done
node "$check" --url http://127.0.0.1:4311/ --out "../shots-$1"
rc=$?
echo "render $1 rc=$rc"
kill -- -"$pid" 2>/dev/null
kill "$pid" 2>/dev/null
wait 2>/dev/null
exit $rc
