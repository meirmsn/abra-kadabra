#!/usr/bin/env node
// The fixture's build and serve tool, a workspace package: found from apps/web only through
// apps/web/node_modules/.bin, which pnpm creates. `build <src> <out>` copies the page and writes
// build.txt (BUILD_SHA); `serve <dir> <port>` serves <dir> on 127.0.0.1:<port> until stopped.
import { cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { join, normalize } from 'node:path';

const [cmd, a, b] = process.argv.slice(2);
if (cmd === 'build') {
  mkdirSync(b, { recursive: true });
  cpSync(a, b, { recursive: true });
  writeFileSync(join(b, 'build.txt'), `${process.env.BUILD_SHA || 'unknown'}\n`);
  console.log(`built ${b}`);
} else if (cmd === 'serve') {
  createServer((req, res) => {
    const path = normalize(new URL(req.url, 'http://x').pathname).replace(/^\/+/, '') || 'index.html';
    try {
      res.end(readFileSync(join(a, path)));
    } catch {
      res.statusCode = 404;
      res.end('not found');
    }
  }).listen(Number(b), '127.0.0.1');
} else {
  console.error('usage: site-tool build <src> <out> | serve <dir> <port>');
  process.exit(2);
}
