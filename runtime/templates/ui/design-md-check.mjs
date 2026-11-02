#!/usr/bin/env node
// DESIGN.md shape check (devshop UI baseline; copy unchanged into a project's scripts/ui/). The
// project's DESIGN.md, in gstack's spec format as the devshop writes it, has the front matter the
// devshop relies on (colors in light and dark, typography, spacing, rounded, under the baseline's
// token names) and a Decisions section, and the theme CSS is derived from it: every front-matter
// token equals its theme token, and every literal colour, --space-*, --radius* and --font-* family
// in the theme is one the front matter names. Spec: specs/design-md-check.md in the devshop.
// Usage: scripts/ui/design-md-check.mjs --theme <theme.css> <DESIGN.md>
// Exit 0 = clean; 1 = findings; 2 = couldn't judge (bad arguments, a missing file, no front
// matter, YAML outside the block-mapping subset, a theme of another shape). Never a pass when it
// can't judge.
import { readFileSync } from 'node:fs';

const NAME = 'design-md-check';
const DARK_SELECTOR = ':root[data-theme="dark"]';
const SYSTEM_DARK_MEDIA = '(prefers-color-scheme: dark)';
const SYSTEM_DARK_SELECTOR = ':root:not([data-theme="light"])';
const GROUPS = ['colors', 'typography', 'spacing', 'rounded'];
const REQUIRED_COLOURS = [
  'background',
  'foreground',
  'primary',
  'primary-foreground',
  'muted-foreground',
  'border',
];
const KEY = /^[a-z0-9-]+$/;
const LENGTH = /^(0|-?\d*\.?\d+(px|rem|em|%))$/;
const REF = /^\{([a-zA-Z0-9_.-]+)\}$/;
const MAX_HOPS = 10;

function cantJudge(msg) {
  console.error(`${NAME}: can't judge: ${msg}`);
  process.exit(2);
}

function read(file) {
  try {
    return readFileSync(file, 'utf8');
  } catch (e) {
    cantJudge(`can't read ${file} (${e.code || e.message})`);
  }
}

const findings = [];
const find = (rule, msg) => findings.push(`${NAME}: ${rule}: ${msg}`);

// --- Arguments ---------------------------------------------------------------------------------
const USAGE = `usage: ${NAME}.mjs --theme <theme.css> <DESIGN.md>`;
const args = process.argv.slice(2);
const ti = args.indexOf('--theme');
if (ti < 0 || ti + 1 >= args.length) cantJudge(USAGE);
const themeFile = args[ti + 1];
if (themeFile === '') cantJudge(`--theme names no file (${USAGE})`);
const rest = args.filter((_, k) => k !== ti && k !== ti + 1);
if (rest.length !== 1) cantJudge(USAGE);
const designFile = rest[0];

// --- The front matter: a block-YAML subset read here, so the check stays one file -------------
// Mappings to any depth, bare and quoted scalars, > and | block scalars, lists of scalars, and
// comments. Flow style, anchors, aliases, tags and tab indents are can't judge, naming the line.
const designText = read(designFile).replace(/^﻿/, '').replace(/\r\n/g, '\n');
if (!designText.startsWith('---\n'))
  cantJudge(
    `${designFile}: no front matter (the file must open with a --- line)`
  );
const designLines = designText.split('\n');
let close = -1;
for (let i = 1; i < designLines.length; i++) {
  if (/^---[ \t]*$/.test(designLines[i])) {
    close = i;
    break;
  }
}
if (close < 0)
  cantJudge(`${designFile}: the front matter has no closing --- line`);
const body = designLines.slice(close + 1);

// items: the front matter's lines that carry content, with their indent and line number.
const items = [];
for (let i = 1; i < close; i++) {
  const raw = designLines[i];
  if (/^\s*(#.*)?$/.test(raw)) continue;
  const lead = raw.match(/^[ \t]*/)[0];
  if (lead.includes('\t'))
    cantJudge(
      `${designFile}:${i + 1}: a tab indent; the front matter is indented with spaces`
    );
  items.push({ indent: lead.length, text: raw.trim(), line: i + 1 });
}
let pos = 0;
const where = (it) => `${designFile}:${it.line}`;

// scalar(text, it): a scalar's value; a trailing comment is dropped; flow style, anchors, aliases
// and tags are can't judge.
function scalar(text, it) {
  const s = text.trim();
  if (s === '') return '';
  const q = s[0];
  if (q === '"' || q === "'") {
    let end = -1;
    for (let k = 1; k < s.length; k++) {
      if (q === '"' && s[k] === '\\') {
        k++;
        continue;
      }
      if (s[k] === q) {
        if (q === "'" && s[k + 1] === "'") {
          k++;
          continue;
        }
        end = k;
        break;
      }
    }
    if (end < 0) cantJudge(`${where(it)}: an unclosed quote`);
    const tail = s.slice(end + 1).trim();
    if (tail !== '' && !tail.startsWith('#'))
      cantJudge(`${where(it)}: text after the closing quote: '${tail}'`);
    const inner = s.slice(1, end);
    if (q === "'") return inner.replace(/''/g, "'");
    try {
      return JSON.parse(`"${inner}"`);
    } catch {
      cantJudge(`${where(it)}: can't read the escapes in "${inner}"`);
    }
  }
  const bare = s.replace(/\s+#.*$/, '').trim();
  if (/^[{[]/.test(bare))
    cantJudge(`${where(it)}: flow style ('${bare}'); write block mappings`);
  if (/^[&*!]/.test(bare))
    cantJudge(`${where(it)}: an anchor, alias or tag ('${bare}')`);
  return bare;
}

// key(text): {key, rest} for a mapping line, or null.
function keyOf(text, it) {
  let m = text.match(/^"((?:[^"\\]|\\.)*)"\s*:(?:\s+(.*))?$/);
  if (m) return { key: JSON.parse(`"${m[1]}"`), rest: m[2] ?? '' };
  m = text.match(/^'((?:[^']|'')*)'\s*:(?:\s+(.*))?$/);
  if (m) return { key: m[1].replace(/''/g, "'"), rest: m[2] ?? '' };
  m = text.match(/^([^\s"'#&*!{[][^:]*?)\s*:(?:\s+(.*))?$/);
  if (m) return { key: m[1], rest: m[2] ?? '' };
  if (/^[&*!{[]/.test(text))
    cantJudge(`${where(it)}: flow style, an anchor, alias or tag ('${text}')`);
  return null;
}

function blockScalar(indicator, indent) {
  const parts = [];
  while (pos < items.length && items[pos].indent > indent)
    parts.push(items[pos++].text);
  return parts.join(indicator.startsWith('>') ? ' ' : '\n');
}

function parseMap(indent, path) {
  const out = {};
  while (pos < items.length && items[pos].indent === indent) {
    const it = items[pos];
    if (/^-(\s|$)/.test(it.text))
      cantJudge(`${where(it)}: a list where a mapping is expected`);
    const kv = keyOf(it.text, it);
    if (!kv) cantJudge(`${where(it)}: can't read '${it.text}'`);
    const here = path ? `${path}.${kv.key}` : kv.key;
    if (kv.key in out)
      find('duplicate-key', `${here} is given twice (line ${it.line})`);
    pos++;
    const rest = kv.rest.replace(/^\s+#.*$/, '');
    if (rest.trim() === '' || /^#/.test(rest.trim())) {
      if (pos < items.length && items[pos].indent > indent)
        out[kv.key] = parseBlock(items[pos].indent, here);
      else out[kv.key] = null;
    } else if (/^[>|][-+]?(\s+#.*)?$/.test(rest.trim())) {
      out[kv.key] = blockScalar(rest.trim(), indent);
    } else {
      out[kv.key] = scalar(rest, it);
    }
  }
  if (pos < items.length && items[pos].indent > indent)
    cantJudge(
      `${where(items[pos])}: indented further than the mapping it follows`
    );
  return out;
}

function parseList(indent, path) {
  const out = [];
  while (pos < items.length && items[pos].indent === indent) {
    const it = items[pos];
    const m = it.text.match(/^-(?:\s+(.*))?$/);
    if (!m) cantJudge(`${where(it)}: a mapping where a list is expected`);
    pos++;
    if (m[1] === undefined || m[1].trim() === '') {
      if (pos < items.length && items[pos].indent > indent)
        cantJudge(
          `${where(items[pos])}: a nested block in a list; lists hold scalars only (${path})`
        );
      out.push('');
    } else if (keyOf(m[1], it) && !/^["']/.test(m[1])) {
      cantJudge(
        `${where(it)}: a mapping in a list; lists hold scalars only (${path})`
      );
    } else out.push(scalar(m[1], it));
  }
  return out;
}

function parseBlock(indent, path) {
  return /^-(\s|$)/.test(items[pos].text)
    ? parseList(indent, path)
    : parseMap(indent, path);
}

let fm = {};
if (items.length > 0) {
  if (items[0].indent !== 0)
    cantJudge(`${where(items[0])}: the front matter starts indented`);
  fm = parseBlock(0, '');
  if (Array.isArray(fm))
    cantJudge(`${designFile}: the front matter is a list, not a mapping`);
}

// --- {path} references, within the four groups --------------------------------------------------
const isMap = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
function lookup(path) {
  let cur = fm;
  for (const part of path.split('.')) {
    if (!isMap(cur) || !(part in cur)) return undefined;
    cur = cur[part];
  }
  return cur;
}
// resolveRef(value, at): the value a {path} chain ends in, or null after a bad-reference finding.
function resolveRef(value, at) {
  let cur = value;
  for (let hop = 0; typeof cur === 'string' && REF.test(cur); hop++) {
    const target = cur.match(REF)[1];
    const next = lookup(target);
    if (
      hop >= MAX_HOPS ||
      next === undefined ||
      isMap(next) ||
      Array.isArray(next)
    ) {
      find(
        'bad-reference',
        `${at} refers to {${target}}, which names no value`
      );
      return null;
    }
    cur = next;
  }
  return cur === null || cur === undefined ? null : String(cur);
}

// --- The shape ---------------------------------------------------------------------------------
for (const g of GROUPS) {
  if (!(g in fm)) find('missing-group', `the front matter has no '${g}'`);
  else if (fm[g] === null)
    fm[g] = {}; // a key with nothing under it: an empty group
  else if (!isMap(fm[g]))
    find('not-a-mapping', `'${g}' is not a mapping of names to values`);
}
const group = (g) => (isMap(fm[g]) ? fm[g] : {});

const isColourToken = (v) => /^(#[0-9a-f]{3,8}|oklch\(.*\))$/i.test(v);
const colours = {}; // name -> value, {path} resolved, bad values dropped
for (const [k, raw] of Object.entries(group('colors'))) {
  if (!KEY.test(k)) {
    find(
      'bad-key',
      `colors.${k}: a key is lower-case letters, digits and hyphens`
    );
    continue;
  }
  const base = k.startsWith('dark-') ? k.slice(5) : k;
  if (k.startsWith('dark-') && !(base in group('colors')))
    find('dark-without-light', `colors.${k} has no light value colors.${base}`);
  if (!k.startsWith('dark-') && !(`dark-${k}` in group('colors')))
    find(
      'colour-without-dark',
      `colors.${k} has no dark value colors.dark-${k}`
    );
  if (raw === null || String(raw).trim() === '') {
    find(
      'not-a-colour',
      `colors.${k} is empty; a bare # colour reads as a YAML comment, so quote it`
    );
    continue;
  }
  const v = resolveRef(raw, `colors.${k}`);
  if (v === null) continue;
  if (!isColourToken(v)) {
    find(
      'not-a-colour',
      `colors.${k} is '${v}'; a colour is hex or oklch(), what tokens-check reads`
    );
    continue;
  }
  colours[k] = v;
}
for (const name of REQUIRED_COLOURS)
  if (!(name in group('colors')))
    find('missing-colour', `colors.${name} is not named`);

const fonts = {}; // role -> family list
for (const [role, def] of Object.entries(group('typography'))) {
  if (!KEY.test(role) || role === 'sans') {
    find(
      'bad-key',
      `typography.${role}: ${role === 'sans' ? "'sans' is body's token name" : 'a role is lower-case letters, digits and hyphens'}`
    );
    continue;
  }
  if (!isMap(def)) {
    find('not-a-mapping', `typography.${role} is not a mapping`);
    continue;
  }
  if ('fontFamily' in def) {
    if (def.fontFamily === null) {
      find('empty-font', `typography.${role}.fontFamily is empty`);
      continue;
    }
    const v = resolveRef(def.fontFamily, `typography.${role}.fontFamily`);
    if (v === null) continue;
    if (v.trim() === '')
      find('empty-font', `typography.${role}.fontFamily is empty`);
    else fonts[role] = v;
  }
}
if (
  isMap(fm.typography) &&
  !('body' in fonts) &&
  !findings.some((f) => f.includes('typography.body.fontFamily'))
)
  find('missing-font', 'typography.body.fontFamily is not given');

const lengths = (g, out) => {
  for (const [k, raw] of Object.entries(group(g))) {
    if (!KEY.test(k)) {
      find(
        'bad-key',
        `${g}.${k}: a key is lower-case letters, digits and hyphens`
      );
      continue;
    }
    if (raw === null || String(raw).trim() === '') {
      find('not-a-length', `${g}.${k} is empty`);
      continue;
    }
    const v = resolveRef(raw, `${g}.${k}`);
    if (v === null) continue;
    if (!LENGTH.test(v)) {
      find(
        'not-a-length',
        `${g}.${k} is '${v}'; a length is a number with px, rem, em or %, or 0`
      );
      continue;
    }
    out[k] = v;
  }
};
const spacing = {};
lengths('spacing', spacing);
if (isMap(fm.spacing) && Object.keys(fm.spacing).length === 0)
  find('empty-group', 'spacing names no step');
const rounded = {};
lengths('rounded', rounded);
if (isMap(fm.rounded) && !('default' in fm.rounded))
  find('missing-default', 'rounded.default is not given');

// The Decisions section: a ## heading outside code fences with content under it.
{
  let fence = null;
  let inDecisions = false;
  let content = false;
  let seen = false;
  for (const line of body) {
    const f = line.match(/^(```|~~~)/);
    if (f && fence === null) {
      fence = f[1];
      if (inDecisions) content = true;
      continue;
    }
    if (f && fence === f[1]) {
      fence = null;
      continue;
    }
    if (fence !== null) {
      if (inDecisions) content = true;
      continue;
    }
    const h = line.match(/^##\s+(.+?)\s*$/);
    if (h) {
      inDecisions = /^decisions( log)?$/i.test(h[1]);
      if (inDecisions) seen = true;
      continue;
    }
    if (inDecisions && line.trim() !== '') content = true;
  }
  if (!seen) find('no-decisions', 'the body has no "## Decisions" section');
  else if (!content)
    find('no-decisions', 'the "## Decisions" section is empty');
}

// --- The theme, read as tokens-check.mjs reads it -----------------------------------------------
const norm = (s) => s.replace(/\s+/g, ' ').replace(/'/g, '"').trim();
function rules(css, media = null, out = []) {
  let i = 0;
  while (i < css.length) {
    const open = css.indexOf('{', i);
    if (open < 0) break;
    const head = css.slice(i, open);
    let depth = 1;
    let j = open + 1;
    for (; j < css.length && depth > 0; j++) {
      if (css[j] === '{') depth++;
      else if (css[j] === '}') depth--;
    }
    if (depth > 0) cantJudge('unbalanced braces in the theme');
    const bodyCss = css.slice(open + 1, j - 1);
    const prelude = norm(head.slice(head.lastIndexOf(';') + 1));
    if (prelude.startsWith('@media'))
      rules(bodyCss, norm(prelude.slice(6)), out);
    else if (prelude.startsWith('@'))
      rules(bodyCss, media === null ? prelude : `${media} ${prelude}`, out);
    else out.push({ media, selector: prelude, body: bodyCss });
    i = j;
  }
  return out;
}
function decls(bodyCss) {
  const out = {};
  for (const part of bodyCss.split(';')) {
    const m = part.match(/^\s*(--[A-Za-z0-9_-]+)\s*:\s*([\s\S]+?)\s*$/);
    if (m) out[m[1]] = norm(m[2]);
  }
  return out;
}
const themeCss = read(themeFile).replace(/\/\*[\s\S]*?\*\//g, '');
const light = {};
let dark = null;
let systemDark = null;
for (const r of rules(themeCss)) {
  const d = decls(r.body);
  if (r.media === null && r.selector === ':root') Object.assign(light, d);
  else if (r.media === null && r.selector === DARK_SELECTOR)
    dark = { ...dark, ...d };
  else if (r.media === SYSTEM_DARK_MEDIA && r.selector === SYSTEM_DARK_SELECTOR)
    systemDark = { ...systemDark, ...d };
  else if (Object.keys(d).length > 0)
    cantJudge(
      `${themeFile}: '${r.selector}'${r.media ? ` in @media ${r.media}` : ''} declares custom properties; only :root, ${DARK_SELECTOR} and ${SYSTEM_DARK_SELECTOR} in @media ${SYSTEM_DARK_MEDIA} may`
    );
}
if (Object.keys(light).length === 0)
  cantJudge(`${themeFile}: no :root rule with tokens`);
if (dark === null) cantJudge(`${themeFile}: no dark rule '${DARK_SELECTOR}'`);
if (systemDark === null)
  cantJudge(
    `${themeFile}: no dark rule '${SYSTEM_DARK_SELECTOR}' in @media ${SYSTEM_DARK_MEDIA}`
  );

// --- The derivation ------------------------------------------------------------------------------
// resolve(theme, value): follows var() within the theme (fallbacks ignored), or null if unresolved.
function resolve(theme, value, depth = 0) {
  const m = value.match(/^var\(\s*(--[A-Za-z0-9_-]+)\s*(?:,[\s\S]*)?\)$/);
  if (!m) return value;
  if (depth > MAX_HOPS || !(m[1] in theme)) return null;
  return resolve(theme, theme[m[1]], depth + 1);
}
// same(a, b): equal as text once whitespace is collapsed, case folded, quotes around names dropped.
const canon = (s) =>
  norm(s)
    .toLowerCase()
    .replace(/"([^"]*)"/g, '$1')
    .replace(/\s*,\s*/g, ',')
    .replace(/\(\s+/g, '(')
    .replace(/\s+\)/g, ')');
const same = (a, b) => canon(a) === canon(b);

// expected: token -> {light, dark, from}; the light value from the front matter, the dark where it has one.
const expected = {};
const expect = (token, from, lightValue, darkValue) => {
  expected[token] = { from, light: lightValue, dark: darkValue };
};
for (const [k, v] of Object.entries(colours)) {
  if (k.startsWith('dark-')) continue;
  expect(`--${k}`, `colors.${k}`, v, colours[`dark-${k}`]);
}
for (const [k, v] of Object.entries(colours))
  if (k.startsWith('dark-') && !(k.slice(5) in colours))
    expect(`--${k.slice(5)}`, `colors.${k}`, undefined, v);
for (const [role, v] of Object.entries(fonts))
  expect(
    role === 'body'
      ? '--font-sans'
      : role === 'mono'
        ? '--font-mono'
        : `--font-${role}`,
    `typography.${role}.fontFamily`,
    v
  );
for (const [k, v] of Object.entries(spacing))
  expect(`--space-${k}`, `spacing.${k}`, v);
for (const [k, v] of Object.entries(rounded))
  expect(k === 'default' ? '--radius' : `--radius-${k}`, `rounded.${k}`, v);

const darkAll = { ...light, ...dark };
const systemDarkAll = { ...light, ...systemDark };
for (const [token, e] of Object.entries(expected)) {
  if (e.light !== undefined) {
    if (!(token in light))
      find(
        'theme-missing-token',
        `${token} (${e.from}) is not declared in :root`
      );
    else {
      const got = resolve(light, light[token]);
      if (got !== null && !same(got, e.light))
        find(
          'theme-differs',
          `${token} is '${light[token]}' in :root but ${e.from} is '${e.light}'`
        );
    }
  }
  if (e.dark !== undefined) {
    const from = `colors.dark-${token.slice(2)}`;
    for (const [ruleName, rule, all] of [
      [DARK_SELECTOR, dark, darkAll],
      [
        `the system-dark rule ${SYSTEM_DARK_SELECTOR}`,
        systemDark,
        systemDarkAll,
      ],
    ]) {
      if (!(token in rule))
        find(
          'theme-missing-token',
          `${token} (${from}) is not declared in ${ruleName}`
        );
      else {
        const got = resolve(all, rule[token]);
        if (got !== null && !same(got, e.dark))
          find(
            'theme-differs',
            `${token} is '${rule[token]}' in ${ruleName} but ${from} is '${e.dark}'`
          );
      }
    }
  }
}

// The other way: a literal the front matter doesn't name. var() aliases are derived, not findings.
const NAMED_COLOURS = new Set(
  'aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen transparent currentcolor'.split(
    ' '
  )
);
const isColourByShape = (v) =>
  /^(#[0-9a-f]{3,8}|(oklch|oklab|rgba?|hsla?|hwb|lab|lch|color|color-mix|light-dark)\(.*\))$/i.test(
    v
  ) || NAMED_COLOURS.has(v.toLowerCase());
const isFamilyList = (v) =>
  /,|"/.test(v) ||
  /(^|\s)(serif|sans-serif|monospace|system-ui|ui-monospace|ui-serif|ui-sans-serif|ui-rounded|cursive|fantasy|math|emoji)(\s|$)/i.test(
    v
  );
const unnamedShape = (token, value) =>
  isColourByShape(value) ||
  token.startsWith('--space-') ||
  token.startsWith('--radius') ||
  (token.startsWith('--font-') && isFamilyList(value));
for (const [ruleName, rule, isDark] of [
  [':root', light, false],
  [DARK_SELECTOR, dark, true],
  [`the system-dark rule ${SYSTEM_DARK_SELECTOR}`, systemDark, true],
]) {
  for (const [token, value] of Object.entries(rule)) {
    if (/^var\(/.test(value)) continue;
    const e = expected[token];
    const named = e && (isDark ? e.dark !== undefined : e.light !== undefined);
    if (named || !unnamedShape(token, value)) continue;
    const want = isDark ? `colors.dark-${token.slice(2)}` : `the front matter`;
    find(
      'theme-not-in-design',
      `${token} is '${value}' in ${ruleName}, a value ${want === 'the front matter' ? 'the front matter' : want} doesn't name`
    );
  }
}

for (const f of findings) console.log(f);
if (findings.length > 0) {
  console.log(`${NAME}: ${findings.length} finding(s)`);
  process.exit(1);
}
console.log(
  `${NAME}: ok, ${Object.keys(expected).length} tokens derived from ${designFile} in ${themeFile}`
);
