#!/usr/bin/env node
// Copies shadcn/ui components into a Next.js project at the project's own shadcn/ui version
// (runtime/stacks/nextjs-supabase/README.md § UI). The project pins `shadcn` in its package.json,
// exact; this reads that version and fetches each component's source from shadcn/ui's release tag
// `shadcn@<version>` on GitHub (the new-york-v4 style), following the file's own imports:
//   @/registry/new-york-v4/ui/<name>    -> that component too, as @/components/ui/<name>
//   @/registry/new-york-v4/hooks/<name> -> the hook, as @/hooks/<name>
//   @/registry/new-york-v4/lib/utils, and the bare `cn` the components import -> lib/utils.ts, as
//                                          @/lib/utils (it re-exports shadcn/ui's `cn` package)
//   any other package                  -> installed with `npm install --save-exact` if the project
//                                          lacks it (react, react-dom and next aside)
// It writes components/ui/, hooks/ and lib/ at the project's root. A file that exists and differs is
// shown as a diff and nothing is written. Nothing it downloads is run.
// Usage: shadcn-add.mjs <project> <component>...
// SHADCN_SOURCE overrides the source's base ({version} is replaced), for tests: a URL or a directory.
// Exit 0 = added (or already identical); 1 = a file differs (shown, nothing written); 2 = couldn't
// run (no package.json, no exact shadcn version, a component or file not at the tag, an import it
// doesn't know, a failed install). Never a pass when it can't run.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const DEFAULT_SOURCE =
  'https://raw.githubusercontent.com/shadcn-ui/ui/shadcn%40{version}/apps/v4/registry/new-york-v4';
const REG = '@/registry/new-york-v4/';
const PROVIDED = new Set(['react', 'react-dom', 'next']);

function cant(msg) {
  console.error(`shadcn-add: can't run: ${msg}`);
  process.exit(2);
}

const [projectArg, ...names] = process.argv.slice(2);
if (!projectArg || names.length === 0)
  cant('usage: shadcn-add.mjs <project> <component>...');
for (const n of names)
  if (!/^[a-z0-9][a-z0-9-]*$/.test(n)) cant(`'${n}' is not a component name`);
const project = resolve(projectArg);

let pkg;
try {
  pkg = JSON.parse(readFileSync(join(project, 'package.json'), 'utf8'));
} catch (e) {
  cant(`can't read ${projectArg}/package.json (${e.code || e.message})`);
}
const version = pkg.devDependencies?.shadcn ?? pkg.dependencies?.shadcn;
if (version === undefined)
  cant('package.json has no `shadcn`; pin the version the project uses, exact');
if (!/^\d+\.\d+\.\d+$/.test(version))
  cant(`package.json's shadcn is '${version}', not an exact version (x.y.z)`);
const base = (process.env.SHADCN_SOURCE || DEFAULT_SOURCE).replaceAll(
  '{version}',
  version
);

// fetchSource(rel): the file's text at the tag, or null when the tag has no such file.
function fetchSource(rel) {
  if (/^https?:\/\//.test(base)) {
    const r = spawnSync(
      'curl',
      ['-fsSL', '--max-time', '60', `${base}/${rel}`],
      {
        encoding: 'utf8',
      }
    );
    if (r.error) cant(`curl can't run (${r.error.code || r.error.message})`);
    if (r.status === 22) return null; // an HTTP error: not at the tag
    if (r.status !== 0)
      cant(`can't fetch ${base}/${rel} (curl exit ${r.status})`);
    return r.stdout;
  }
  const p = join(base, rel);
  if (!existsSync(p)) return null;
  try {
    return readFileSync(p, 'utf8');
  } catch (e) {
    cant(`can't read ${p} (${e.code || e.message})`);
  }
}

const out = new Map(); // project path -> text
const packages = new Set();
const queue = names.map((n) => ({ kind: 'ui', name: n }));
const seen = new Set();

// The import specifiers in a file: from '…', import '…', import('…').
const SPEC = /(\bfrom\s*|\bimport\s*\(?\s*)(['"])([^'"\n]+)\2/g;

function rewrite(text, file) {
  return text.replace(SPEC, (whole, lead, q, spec) => {
    let to;
    if (spec === 'cn' && file !== 'lib/utils.ts') {
      queue.push({ kind: 'lib', name: 'utils' });
      to = '@/lib/utils';
    } else if (spec === `${REG}lib/utils`) {
      queue.push({ kind: 'lib', name: 'utils' });
      to = '@/lib/utils';
    } else if (spec.startsWith(`${REG}ui/`)) {
      const n = spec.slice(`${REG}ui/`.length);
      queue.push({ kind: 'ui', name: n });
      to = `@/components/ui/${n}`;
    } else if (spec.startsWith(`${REG}hooks/`)) {
      const n = spec.slice(`${REG}hooks/`.length);
      queue.push({ kind: 'hooks', name: n });
      to = `@/hooks/${n}`;
    } else if (spec.startsWith('@/') || spec.startsWith('.')) {
      cant(
        `${file} imports '${spec}', which this script doesn't know how to place`
      );
    } else if (!spec.startsWith('node:')) {
      const parts = spec.split('/');
      const name = spec.startsWith('@')
        ? parts.slice(0, 2).join('/')
        : parts[0];
      if (!PROVIDED.has(name)) packages.add(name);
      return whole;
    } else return whole;
    return `${lead}${q}${to}${q}`;
  });
}

while (queue.length > 0) {
  const { kind, name } = queue.shift();
  const key = `${kind}/${name}`;
  if (seen.has(key)) continue;
  seen.add(key);
  const tries =
    kind === 'ui'
      ? [`ui/${name}.tsx`]
      : kind === 'lib'
        ? [`lib/${name}.ts`]
        : [`hooks/${name}.ts`, `hooks/${name}.tsx`];
  let rel = null;
  let text = null;
  for (const t of tries) {
    text = fetchSource(t);
    if (text !== null) {
      rel = t;
      break;
    }
  }
  if (text === null)
    cant(
      `shadcn@${version} has no ${kind === 'ui' ? 'component' : kind} '${name}' (${tries.join(' or ')})`
    );
  const dest = rel.startsWith('ui/') ? `components/${rel}` : rel;
  out.set(dest, rewrite(text, rel));
}

// A file already there and different: show it, write nothing.
let differ = false;
for (const [dest, text] of out) {
  const target = join(project, dest);
  if (!existsSync(target)) continue;
  const have = readFileSync(target, 'utf8');
  if (have === text) continue;
  differ = true;
  console.log(`differs: ${dest} (left as it is):`);
  const d = spawnSync('diff', ['-u', target, '-'], {
    input: text,
    encoding: 'utf8',
  });
  console.log((d.stdout || '').split('\n').slice(2).join('\n'));
}
if (differ) {
  console.log(
    'shadcn-add: nothing written; merge the differences by hand or move the files aside'
  );
  process.exit(1);
}

const have = new Set(
  ['dependencies', 'devDependencies', 'peerDependencies'].flatMap((k) =>
    Object.keys(pkg[k] || {})
  )
);
const missing = [...packages].filter((p) => !have.has(p)).sort();
if (missing.length > 0) {
  console.log(`shadcn-add: npm install --save-exact ${missing.join(' ')}`);
  const r = spawnSync(
    'npm',
    ['install', '--save-exact', '--no-audit', '--no-fund', ...missing],
    {
      cwd: project,
      stdio: 'inherit',
    }
  );
  if (r.error || r.status !== 0)
    cant(
      `npm install failed (${r.error ? r.error.code || r.error.message : `exit ${r.status}`}); nothing written`
    );
}

for (const [dest, text] of out) {
  const target = join(project, dest);
  if (existsSync(target)) {
    console.log(`same: ${dest}`);
    continue;
  }
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, text);
  console.log(`added: ${dest}`);
}
console.log(`shadcn-add: ok, ${out.size} file(s) from shadcn@${version}`);
