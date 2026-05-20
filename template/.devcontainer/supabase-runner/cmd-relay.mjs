#!/usr/bin/env node
// What: Whitelisted RPC relay for compose isolation. Listens on
//       0.0.0.0:9000 inside the supabase-runner container. The workspace
//       container has no docker socket, so it cannot run
//       `docker compose exec supabase-runner ...`; instead it curls one
//       of the relay endpoints below to drive supabase lifecycle commands.
// Why:  Centralizes the docker-exposing surface in a tiny, auditable JS
//       file with an explicit allowlist. Adding a command means editing
//       the ALLOWED map; nothing else.
// Does NOT: stream stdout — it buffers stdout so the supabase exit code
//       can be mapped to an HTTP status (200 / 500). This lets workspace
//       wrappers like `pnpm db:gen-types` use `curl -fsS -o <file>`
//       without worrying about overwriting the types file with an error
//       message. Live progress for slow commands (`db reset`) is visible
//       on the runner side via `docker logs supabase-runner -f`.
//       Stderr always goes to the runner's process.stderr (visible via
//       `docker logs`) so it never corrupts stdout-only response bodies.
//
// Shutdown: on SIGTERM / SIGINT (fired by `docker compose stop`, which is
//       what VS Code Dev Containers runs when you close the window or
//       Stop Container), runs `supabase stop` before exiting. Without
//       this, the spawned supabase_* sibling containers — owned by the
//       host docker engine, NOT by this compose project — stay running
//       after the devcontainer goes down. compose.yml bumps
//       stop_grace_period to 30s so the stop has room to finish before
//       docker SIGKILLs us.

import { createServer } from "node:http";
import { spawn } from "node:child_process";

const ALLOWED = {
  "db-reset":  ["supabase", "db", "reset"],
  "status":    ["supabase", "status"],
  "start":     ["supabase", "start"],
  "stop":      ["supabase", "stop"],
  "gen-types": ["supabase", "gen", "types", "typescript", "--local"],
};

let shuttingDown = false;
function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[relay] ${signal} — running 'supabase stop' before exit`);
  const p = spawn("supabase", ["stop"], { stdio: "inherit" });
  // 25s budget — compose's stop_grace_period is 30s; leave 5s slack so the
  // process exits cleanly instead of getting SIGKILL'd mid-teardown.
  const kill = setTimeout(() => {
    console.error("[relay] supabase stop exceeded 25s; forcing exit");
    process.exit(1);
  }, 25_000);
  kill.unref();
  p.on("close", (code) => {
    clearTimeout(kill);
    console.log(`[relay] supabase stop exit ${code}; relay exiting`);
    process.exit(code ?? 0);
  });
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT",  () => shutdown("SIGINT"));

createServer((req, res) => {
  const key = req.url.replace(/^\//, "").split("?")[0];
  const cmd = ALLOWED[key];
  if (!cmd) {
    res.writeHead(403, { "content-type": "text/plain" });
    res.end(`blocked: ${key}\n`);
    return;
  }
  console.log(`[relay] ${new Date().toISOString()} ${key}`);
  const p = spawn(cmd[0], cmd.slice(1));
  let stdout = "";
  p.stdout.on("data", (chunk) => { stdout += chunk; });
  p.stderr.on("data", (chunk) => process.stderr.write(`[${key}] ${chunk}`));
  p.on("close", (code) => {
    res.writeHead(code === 0 ? 200 : 500, {
      "content-type": "text/plain",
      "x-exit-code": String(code),
    });
    res.end(stdout);
    console.log(`[relay]   ${key} exit ${code}`);
  });
}).listen(9000, "0.0.0.0", () => console.log("[relay] listening on :9000"));
