#!/usr/bin/env node
// Design-token check (devshop UI baseline; copy unchanged into a project's scripts/ui/). Every
// var(--name) in the given files must be defined by the theme for light and dark, the theme's two
// dark rules must agree, and each contrast pair must reach 4.5:1 in both themes (L-78).
// Usage: node tokens-check.mjs --theme <theme.css> <file>...
// Exit 0 = clean; 1 = findings; 2 = couldn't judge (bad arguments, a missing file, a theme of
// another shape, a colour it can't read). Never a pass when it can't judge.
import { readFileSync } from 'node:fs';

const MIN_CONTRAST = 4.5;
const DARK_SELECTOR = ':root[data-theme="dark"]';
const SYSTEM_DARK_MEDIA = '(prefers-color-scheme: dark)';
const SYSTEM_DARK_SELECTOR = ':root:not([data-theme="light"])';

function cantJudge(msg) {
  console.error(`tokens-check: can't judge: ${msg}`);
  process.exit(2);
}

function read(file) {
  try {
    return readFileSync(file, 'utf8');
  } catch (e) {
    cantJudge(`can't read ${file} (${e.code || e.message})`);
  }
}

const norm = (s) => s.replace(/\s+/g, ' ').replace(/'/g, '"').trim();

// rules(css, media): every style rule as {media, selector, body}; at-rules are entered, so a rule
// in @media keeps its condition. Comments are removed first.
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
    const body = css.slice(open + 1, j - 1);
    const prelude = norm(head.slice(head.lastIndexOf(';') + 1));
    if (prelude.startsWith('@media')) rules(body, norm(prelude.slice(6)), out);
    else if (prelude.startsWith('@'))
      rules(body, media === null ? prelude : `${media} ${prelude}`, out);
    else out.push({ media, selector: prelude, body });
    i = j;
  }
  return out;
}

function decls(body) {
  const out = {};
  for (const part of body.split(';')) {
    const m = part.match(/^\s*(--[A-Za-z0-9_-]+)\s*:\s*([\s\S]+?)\s*$/);
    if (m) out[m[1]] = norm(m[2]);
  }
  return out;
}

const args = process.argv.slice(2);
const ti = args.indexOf('--theme');
if (ti < 0 || !args[ti + 1])
  cantJudge('usage: tokens-check.mjs --theme <theme.css> <file>...');
const themeFile = args[ti + 1];
const files = args.filter((_, k) => k !== ti && k !== ti + 1);
if (files.length === 0) cantJudge('no files to check');

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

const findings = [];
const find = (rule, msg) => findings.push(`tokens-check: ${rule}: ${msg}`);

// The two dark rules must be the same palette: one for "system is dark", one for the toggle.
for (const k of new Set([...Object.keys(dark), ...Object.keys(systemDark)])) {
  if (dark[k] !== systemDark[k])
    find(
      'dark-rules-differ',
      `${k} is '${dark[k] ?? '(missing)'}' in ${DARK_SELECTOR} but '${systemDark[k] ?? '(missing)'}' in the system-dark rule`
    );
}
for (const k of Object.keys(dark))
  if (!(k in light)) find('dark-only', `${k} is defined only for dark`);

const darkAll = { ...light, ...dark };

// resolve(theme, value): follows var() within the theme (fallbacks ignored), or null if unresolved.
function resolve(theme, value, depth = 0) {
  const m = value.match(/^var\(\s*(--[A-Za-z0-9_-]+)\s*(?:,[\s\S]*)?\)$/);
  if (!m) return value;
  if (depth > 10 || !(m[1] in theme)) return null;
  return resolve(theme, theme[m[1]], depth + 1);
}
const looksLikeColour = (v) =>
  v !== null && /^(#[0-9a-f]{3,8}|oklch\(|rgba?\(|hsla?\()/i.test(v);
// A literal colour needs a dark value; a var() alias follows its target into dark by itself.
for (const k of Object.keys(light)) {
  if (looksLikeColour(light[k]) && !(k in dark))
    find(
      'light-only-colour',
      `${k} is a colour defined for light but not dark`
    );
}

// Every var() in every file names a token the theme defines.
for (const file of [themeFile, ...files]) {
  const text = file === themeFile ? themeCss : read(file);
  for (const m of text.matchAll(/var\(\s*--([A-Za-z0-9_-]*)(.?)/g)) {
    const name = `--${m[1]}`;
    if (m[1] === '' || !/[\s,)]/.test(m[2])) {
      find(
        'no-literal-name',
        `${file}: 'var(--${m[1]}${m[2]}…' has no literal name, so it can't be checked`
      );
    } else if (!(name in light) && !(name in dark)) {
      find('undefined-token', `${file}: ${name} is not defined by the theme`);
    }
  }
}

// Colour: OKLCH or hex to sRGB channels 0..1 (out-of-gamut clipped per channel), or cantJudge.
function srgb(token, themeName, value) {
  const v = value.toLowerCase();
  let m = v.match(/^#([0-9a-f]{3,8})$/);
  if (m) {
    let h = m[1];
    if (h.length === 3 || h.length === 4) h = [...h].map((c) => c + c).join('');
    if (h.length !== 6 && h.length !== 8)
      cantJudge(`${token} (${themeName}): can't read '${value}'`);
    if (h.length === 8 && h.slice(6) !== 'ff')
      cantJudge(
        `${token} (${themeName}): '${value}' has alpha; contrast pairs must be opaque`
      );
    return [0, 2, 4].map((k) => parseInt(h.slice(k, k + 2), 16) / 255);
  }
  m = v.match(
    /^oklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)(?:deg)?\s*(?:\/\s*([\d.]+)(%?))?\s*\)$/
  );
  if (m) {
    if (m[5] !== undefined && Number(m[5]) / (m[6] ? 100 : 1) < 1)
      cantJudge(
        `${token} (${themeName}): '${value}' has alpha; contrast pairs must be opaque`
      );
    const L = Number(m[1]) / (m[2] ? 100 : 1);
    const C = Number(m[3]);
    const h = (Number(m[4]) * Math.PI) / 180;
    const a = C * Math.cos(h);
    const b = C * Math.sin(h);
    const l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
    const m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
    const s_ = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
    const lin = [
      4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
      -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
      -0.0041960863 * l_ - 0.7034186147 * m_ + 1.707614701 * s_,
    ];
    return lin.map((c) => {
      const x = Math.min(1, Math.max(0, c));
      return x <= 0.0031308 ? 12.92 * x : 1.055 * x ** (1 / 2.4) - 0.055;
    });
  }
  cantJudge(
    `${token} (${themeName}): can't read colour '${value}' (OKLCH or hex)`
  );
}
function luminance(rgb) {
  const [r, g, b] = rgb.map((c) =>
    c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  );
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

const pairs = [
  ['--foreground', '--background'],
  ['--muted-foreground', '--background'],
];
for (const k of Object.keys(light)) {
  const base = k.replace(/-foreground$/, '');
  if (k !== base && k !== '--foreground' && base in light)
    pairs.push([k, base]);
}
for (const [themeName, theme] of [
  ['light', light],
  ['dark', darkAll],
]) {
  for (const [fg, bg] of pairs) {
    if (!(fg in theme) || !(bg in theme)) continue;
    const fv = resolve(theme, theme[fg]);
    const bv = resolve(theme, theme[bg]);
    if (fv === null || bv === null) continue; // an undefined var() is already a finding
    const [l1, l2] = [
      luminance(srgb(fg, themeName, fv)),
      luminance(srgb(bg, themeName, bv)),
    ].sort((x, y) => y - x);
    const ratio = (l1 + 0.05) / (l2 + 0.05);
    if (ratio < MIN_CONTRAST)
      find(
        'contrast',
        `${fg} on ${bg} is ${ratio.toFixed(2)}:1 in ${themeName}, below ${MIN_CONTRAST}:1`
      );
  }
}

for (const f of findings) console.log(f);
if (findings.length > 0) {
  console.log(`tokens-check: ${findings.length} finding(s)`);
  process.exit(1);
}
console.log(
  `tokens-check: ok, ${Object.keys(light).length} tokens, ${pairs.length} contrast pairs, ${files.length} file(s)`
);
