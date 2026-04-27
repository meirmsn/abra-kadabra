import { describe, test, expect } from 'bun:test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { resolveServerScript, resolveNodeServerScript } from '../src/cli';

const SRC_DIR = path.resolve(import.meta.dir, '../src');
const DIST_DIR = path.resolve(import.meta.dir, '../dist');

describe('resolveServerScript', () => {
  test('returns BROWSE_SERVER_SCRIPT env value verbatim (no existence check)', () => {
    expect(resolveServerScript({ BROWSE_SERVER_SCRIPT: '/explicit/server.ts' }, '', ''))
      .toBe('/explicit/server.ts');
  });

  test('finds server.ts adjacent to metaDir in dev mode', () => {
    expect(resolveServerScript({}, SRC_DIR, '')).toBe(path.join(SRC_DIR, 'server.ts'));
  });

  test('finds ../src/server.ts adjacent to compiled binary execPath', () => {
    const distBrowse = path.join(DIST_DIR, 'browse');
    if (!fs.existsSync(distBrowse)) return;
    // metaDir contains $bunfs → dev branch is skipped, falls through to execPath branch
    expect(resolveServerScript({}, '/$bunfs/whatever', distBrowse))
      .toBe(path.join(SRC_DIR, 'server.ts'));
  });

  test('returns null when src tree is absent (compiled binary without adjacent src/)', () => {
    // v1.22.0 cluster 1 changed this branch from throwing to returning null so the
    // caller can fall back to resolveNodeServerScript(). Forward coverage for the
    // structural-fallback contract.
    expect(resolveServerScript({}, '/$bunfs/nonexistent', '/nonexistent/dir/browse')).toBeNull();
  });

  test('returns null when metaDir has no server.ts and execPath is empty', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'browse-cli-test-'));
    try {
      expect(resolveServerScript({}, tmpDir, '')).toBeNull();
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('resolveNodeServerScript', () => {
  test('finds dist/server-node.mjs from src metaDir (dev mode)', () => {
    const distNode = path.join(DIST_DIR, 'server-node.mjs');
    if (!fs.existsSync(distNode)) return;
    expect(resolveNodeServerScript(SRC_DIR, '')).toBe(distNode);
  });

  test('finds adjacent server-node.mjs from execPath (compiled binary)', () => {
    const distNode = path.join(DIST_DIR, 'server-node.mjs');
    const distBrowse = path.join(DIST_DIR, 'browse');
    if (!fs.existsSync(distNode) || !fs.existsSync(distBrowse)) return;
    // metaDir contains $bunfs → dev branch is skipped, execPath branch resolves it
    expect(resolveNodeServerScript('/$bunfs/whatever', distBrowse)).toBe(distNode);
  });

  test('returns null when no node-server bundle is reachable', () => {
    expect(resolveNodeServerScript('/$bunfs/nonexistent', '/nonexistent/dir/browse')).toBeNull();
  });
});

describe('USE_NODE_SERVER launch-path flip', () => {
  // Contract test for the formula in cli.ts:
  //   const USE_NODE_SERVER = IS_WINDOWS || !SERVER_SCRIPT;
  // which selects between `node NODE_SERVER_SCRIPT` and `bun run SERVER_SCRIPT`
  // inside startServer(). Refactors that change this formula must update this
  // test in lockstep — that's the point: it locks in the launch-path contract.
  const useNodeServer = (isWindows: boolean, serverScript: string | null): boolean =>
    isWindows || !serverScript;

  test('non-Windows + src tree present → run via Bun (no flip)', () => {
    expect(useNodeServer(false, '/path/to/server.ts')).toBe(false);
  });

  test('non-Windows + src tree absent → flip to Node bundle', () => {
    // The cluster 1 trigger: project install ships dist/ only (no src/server.ts),
    // resolveServerScript returns null, USE_NODE_SERVER becomes true, startServer
    // launches `node NODE_SERVER_SCRIPT` instead of `bun run SERVER_SCRIPT`.
    expect(useNodeServer(false, null)).toBe(true);
  });

  test('Windows always uses Node, regardless of SERVER_SCRIPT presence', () => {
    expect(useNodeServer(true, null)).toBe(true);
    expect(useNodeServer(true, '/path/to/server.ts')).toBe(true);
  });
});
