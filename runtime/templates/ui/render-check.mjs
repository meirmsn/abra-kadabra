#!/usr/bin/env node
// Render check (devshop UI baseline; copy unchanged into a project's scripts/ui/). Loads a page in
// Chromium at 375 px (phone), 768 px and 1280 px, with the system in light and in dark, and checks:
// a viewport meta; no horizontal overflow; the background follows the system; a theme toggle that
// overrides the system both ways and survives a reload; a <main> that widens on desktop; text
// contrast as painted; 44 px controls; a pressed state on buttons. Writes <width>-<theme>.png.
// Usage: node render-check.mjs --url <url> --out <dir>
// Exit 0 = clean; 1 = findings; 2 = couldn't judge (bad arguments, no Playwright or browser, the
// page didn't load or threw). Never a pass when it can't judge.
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const WIDTHS = [
  { width: 375, height: 812, isMobile: true, hasTouch: true },
  { width: 768, height: 1024, isMobile: false, hasTouch: true },
  { width: 1280, height: 800, isMobile: false, hasTouch: false },
];
const SCHEMES = ['light', 'dark'];
const MIN_TARGET = 44;
const MAX_REPORTED = 5; // elements named per rule and view

function cantJudge(msg) {
  console.error(`render-check: can't judge: ${msg}`);
  process.exit(2);
}

const args = process.argv.slice(2);
const arg = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const url = arg('--url');
const out = arg('--out');
if (!url || !out) cantJudge('usage: render-check.mjs --url <url> --out <dir>');
try {
  mkdirSync(out, { recursive: true });
} catch (e) {
  cantJudge(`can't create ${out} (${e.code || e.message})`);
}

let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch (e) {
  cantJudge(
    `Playwright can't be loaded; install the project's pinned version (npm ci): ${e.message.split('\n')[0]}`
  );
}

let browser;
try {
  browser = await chromium.launch();
} catch (e) {
  cantJudge(
    `the browser can't start (install Chromium for the pinned Playwright): ${e.message.split('\n')[0]}`
  );
}

const findings = [];
const find = (rule, where, msg) =>
  findings.push(`render-check: ${rule} @${where}: ${msg}`);

// open(view, scheme): a fresh context and page, loaded, or cantJudge.
async function open(view, scheme) {
  const context = await browser.newContext({
    viewport: { width: view.width, height: view.height },
    isMobile: view.isMobile,
    hasTouch: view.hasTouch,
    colorScheme: scheme,
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await load(page, errors, () => page.goto(url, { waitUntil: 'load' }));
  return { context, page, errors };
}

async function load(page, errors, go) {
  let response;
  try {
    response = await go();
  } catch (e) {
    await browser.close();
    cantJudge(`the page didn't load: ${e.message.split('\n')[0]}`);
  }
  if (response && response.status() >= 400) {
    await browser.close();
    cantJudge(`the page answered HTTP ${response.status()}`);
  }
  await page.evaluate(() => document.fonts.ready);
  if (errors.length > 0) {
    await browser.close();
    cantJudge(`the page threw: ${errors[0]}`);
  }
}

// Everything measured inside the page. Colours are read through a canvas, so the browser does the
// colour maths (OKLCH, gamut mapping) exactly as it paints.
function inspect({ minTarget, maxReported }) {
  const ctx = document
    .createElement('canvas')
    .getContext('2d', { willReadFrequently: true });
  const rgba = (css) => {
    ctx.clearRect(0, 0, 1, 1);
    ctx.fillStyle = '#000';
    ctx.fillStyle = css;
    ctx.fillRect(0, 0, 1, 1);
    const d = ctx.getImageData(0, 0, 1, 1).data;
    return [d[0], d[1], d[2], d[3] / 255];
  };
  const over = (top, under) =>
    [0, 1, 2].map((k) => top[k] * top[3] + under[k] * (1 - top[3]));
  const lum = (c) => {
    const [r, g, b] = c.map((v) => {
      const x = v / 255;
      return x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const ratio = (a, b) => {
    const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x);
    return (hi + 0.05) / (lo + 0.05);
  };
  const describe = (el) => {
    let s = el.tagName.toLowerCase();
    if (el.id) s += `#${el.id}`;
    if (el.classList.length) s += `.${[...el.classList].join('.')}`;
    const text = (el.textContent || '')
      .trim()
      .replace(/\s+/g, ' ')
      .slice(0, 30);
    return text ? `${s} "${text}"` : s;
  };
  const opacityOf = (el) => {
    let o = 1;
    for (let e = el; e; e = e.parentElement)
      o *= Number(getComputedStyle(e).opacity);
    return o;
  };
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    if (r.width <= 1 && r.height <= 1) return false; // absent or visually hidden (sr-only)
    const cs = getComputedStyle(el);
    return cs.visibility !== 'hidden' && opacityOf(el) > 0;
  };
  const html = document.documentElement;
  const canvasColour = (() => {
    const htmlBg = rgba(getComputedStyle(html).backgroundColor);
    const base =
      matchMedia('(prefers-color-scheme: dark)').matches &&
      getComputedStyle(html).colorScheme.includes('dark')
        ? [18, 18, 18]
        : [255, 255, 255];
    return over(htmlBg, base);
  })();
  const backgroundOf = (el) => {
    const layers = [];
    for (let e = el; e && e !== html; e = e.parentElement)
      layers.push(rgba(getComputedStyle(e).backgroundColor));
    let c = canvasColour;
    for (const layer of layers.reverse()) c = over(layer, c);
    return c;
  };

  const res = { findings: [] };
  const add = (rule, msg) => res.findings.push([rule, msg]);
  const meta = document.querySelector('meta[name="viewport"]');
  res.viewportMeta = !!meta && /width\s*=\s*device-width/.test(meta.content);
  res.background = backgroundOf(document.body).map(Math.round).join(',');
  const main = document.querySelector('main');
  res.mainWidth = main ? main.getBoundingClientRect().width : null;

  // Overflow: scrolling sideways, or a visible element past either edge (overflow-x: hidden on html
  // or body can hide the scroll, not the problem). Inside another clipping container is fine.
  const vw = window.innerWidth;
  if (html.scrollWidth > html.clientWidth + 1)
    add(
      'overflow',
      `the page scrolls sideways (${html.scrollWidth}px wide in ${html.clientWidth}px)`
    );
  const past = [];
  for (const el of document.body.querySelectorAll('*')) {
    if (!visible(el)) continue;
    const r = el.getBoundingClientRect();
    if (r.right <= vw + 1 && r.left >= -1) continue;
    let clipped = false;
    for (
      let a = el.parentElement;
      a && a !== document.body && a !== html;
      a = a.parentElement
    ) {
      if (getComputedStyle(a).overflowX !== 'visible') clipped = true;
    }
    if (!clipped)
      past.push(
        `${describe(el)} spans ${Math.round(r.left)}..${Math.round(r.right)}px`
      );
  }
  if (past.length)
    add(
      'overflow',
      `past the ${vw}px viewport: ${past.slice(0, maxReported).join('; ')}`
    );

  // Contrast of every visible text as painted. Disabled controls are exempt (WCAG 1.4.3).
  const low = [];
  for (const el of document.body.querySelectorAll('*')) {
    const own = [...el.childNodes].some(
      (n) => n.nodeType === Node.TEXT_NODE && n.textContent.trim()
    );
    if (!own || !visible(el)) continue;
    if (el.closest(':disabled, [aria-disabled="true"]')) continue;
    const cs = getComputedStyle(el);
    const bg = backgroundOf(el);
    const fgRaw = rgba(cs.color);
    const fg = over(
      [fgRaw[0], fgRaw[1], fgRaw[2], fgRaw[3] * opacityOf(el)],
      bg
    );
    const size = parseFloat(cs.fontSize);
    const large = size >= 24 || (size >= 18.66 && Number(cs.fontWeight) >= 700);
    const need = large ? 3 : 4.5;
    const got = ratio(fg, bg);
    if (got < need)
      low.push(`${describe(el)} ${got.toFixed(2)}:1 (needs ${need}:1)`);
  }
  if (low.length) add('contrast', low.slice(0, maxReported).join('; '));

  // Touch targets: 44 x 44 px, measured on the label for a labelled checkbox or radio. A link inside
  // a sentence (its parent has text of its own) is exempt (WCAG 2.5.8).
  const small = [];
  const controls =
    'a[href], button, input:not([type="hidden"]), select, textarea, summary, [role="button"]';
  for (const el of document.body.querySelectorAll(controls)) {
    let box = el;
    if (el.matches('input[type="checkbox"], input[type="radio"]')) {
      box =
        el.closest('label') ||
        (el.id &&
          document.querySelector(`label[for="${CSS.escape(el.id)}"]`)) ||
        el;
    }
    if (!visible(box)) continue;
    if (el.matches('a')) {
      const parent = el.parentElement;
      const parentText =
        parent &&
        [...parent.childNodes].some(
          (n) => n.nodeType === Node.TEXT_NODE && n.textContent.trim()
        );
      if (parentText) continue;
    }
    const r = box.getBoundingClientRect();
    if (r.width < minTarget - 0.5 || r.height < minTarget - 0.5)
      small.push(
        `${describe(el)} is ${Math.round(r.width)}x${Math.round(r.height)}px`
      );
  }
  if (small.length)
    add(
      'target-size',
      `under ${minTarget}x${minTarget}px: ${small.slice(0, maxReported).join('; ')}`
    );
  return res;
}

const ctx = { minTarget: MIN_TARGET, maxReported: MAX_REPORTED };
const backgrounds = {};
const mainWidths = {};
let viewportChecked = false;

for (const view of WIDTHS) {
  for (const scheme of SCHEMES) {
    const where = `${view.width}px ${scheme}`;
    const { context, page } = await open(view, scheme);
    const r = await page.evaluate(inspect, ctx);
    if (!viewportChecked) {
      viewportChecked = true;
      if (!r.viewportMeta)
        find(
          'viewport',
          where,
          'no <meta name="viewport" content="width=device-width, …">: phones render it zoomed out'
        );
    }
    for (const [rule, msg] of r.findings) find(rule, where, msg);
    backgrounds[`${view.width}-${scheme}`] = r.background;
    mainWidths[view.width] = r.mainWidth;
    await page.screenshot({
      path: join(out, `${view.width}-${scheme}.png`),
      fullPage: true,
    });
    await context.close();
  }
  if (backgrounds[`${view.width}-light`] === backgrounds[`${view.width}-dark`])
    find(
      'theme-follows-system',
      `${view.width}px`,
      `the page background is the same (rgb ${backgrounds[`${view.width}-light`]}) with the system in light and in dark`
    );
}

if (mainWidths[375] === null) find('main', 'all widths', 'no <main> element');
else if (!(mainWidths[1280] > mainWidths[375] + 1))
  find(
    'responsive',
    '1280px',
    `<main> is ${Math.round(mainWidths[1280])}px wide on desktop, no wider than on a phone (${Math.round(mainWidths[375])}px)`
  );

// Theme toggle: from each system theme, clicking it reaches the other theme; the choice survives a
// reload. Pressed state: pressing each enabled button changes how it looks.
const desktop = WIDTHS[WIDTHS.length - 1];
const bgNow = (page) =>
  page.evaluate(() => {
    const ctx = document.createElement('canvas').getContext('2d');
    ctx.fillStyle = getComputedStyle(document.body).backgroundColor;
    ctx.fillRect(0, 0, 1, 1);
    return [...ctx.getImageData(0, 0, 1, 1).data].join(',');
  });
for (const scheme of SCHEMES) {
  const other = scheme === 'light' ? 'dark' : 'light';
  const where = `${desktop.width}px system ${scheme}`;
  const { context, page, errors } = await open(desktop, scheme);
  const toggle = page.locator('[data-theme-toggle]').first();
  if (
    (await page.locator('[data-theme-toggle]').count()) === 0 ||
    !(await toggle.isVisible())
  ) {
    find(
      'theme-toggle',
      where,
      'no visible theme toggle ([data-theme-toggle])'
    );
    await context.close();
    continue;
  }
  const start = await bgNow(page);
  let reached = false;
  for (let i = 0; i < 3 && !reached; i++) {
    await toggle.click();
    reached = (await bgNow(page)) !== start;
  }
  if (!reached) {
    find(
      'theme-toggle',
      where,
      `three clicks on the toggle never switched the page to ${other}`
    );
  } else {
    const chosen = await bgNow(page);
    await load(page, errors, () => page.reload({ waitUntil: 'load' }));
    if ((await bgNow(page)) !== chosen)
      find(
        'theme-toggle',
        where,
        `the ${other} choice doesn't survive a reload`
      );
  }
  await context.close();
}

{
  const where = `${desktop.width}px light`;
  const { context, page } = await open(desktop, 'light');
  const buttons = page.locator(
    'button:not(:disabled):not([aria-disabled="true"]), .btn:not(:disabled):not([aria-disabled="true"]), [role="button"]:not([aria-disabled="true"])'
  );
  const n = Math.min(await buttons.count(), 20);
  const flat = [];
  const look = (el) => {
    const cs = getComputedStyle(el);
    return [
      cs.transform,
      cs.filter,
      cs.backgroundColor,
      cs.boxShadow,
      cs.color,
      cs.opacity,
      cs.outline,
    ].join('|');
  };
  for (let i = 0; i < n; i++) {
    const b = buttons.nth(i);
    if (!(await b.isVisible())) continue;
    await b.scrollIntoViewIfNeeded();
    const box = await b.boundingBox();
    const before = await b.evaluate(look);
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.waitForTimeout(150);
    const during = await b.evaluate(look);
    await page.mouse.move(0, 0); // release away from it, so the press never becomes a click
    await page.mouse.up();
    if (during === before)
      flat.push(
        await b.evaluate((el) =>
          (el.textContent || el.tagName).trim().slice(0, 30)
        )
      );
  }
  if (flat.length)
    find(
      'pressed-state',
      where,
      `no visible change while pressed: ${flat
        .slice(0, MAX_REPORTED)
        .map((t) => `"${t}"`)
        .join(', ')}`
    );
  await context.close();
}

await browser.close();
for (const f of findings) console.log(f);
if (findings.length > 0) {
  console.log(
    `render-check: ${findings.length} finding(s); screenshots in ${out}`
  );
  process.exit(1);
}
console.log(
  `render-check: ok at ${WIDTHS.map((v) => v.width).join(', ')} px, light and dark; screenshots in ${out}`
);
