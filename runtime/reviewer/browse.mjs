#!/usr/bin/env node
// devshop-browse: the reviewer's one browser command (spec specs/reviewer-browser.md). review.sh
// writes a `devshop-browse` wrapper on the reviewer's PATH that sets the three DEVSHOP_BROWSE_*
// variables and runs this file with the reviewer's arguments, which must be exactly one path
// starting with `/`. It loads that page of the local run at 375, 768 and 1280 px, each with the
// system in light and dark (the render check's widths and themes, specs/ui-baseline.md), with the
// Playwright the project pins (loaded from the project's node_modules), and prints the six
// screenshots' paths and the page's facts as JSON. Only the local run's origin is reached: every
// other request and WebSocket is aborted and listed as blocked, and service workers are blocked.
// This is feedback, not a wall (runtime/reviewer/README.md).
// Exit 0 = browsed; 1 = refused (bad arguments, another origin), nothing loaded; 2 = can't judge
// (no Playwright or browser, the page didn't load).
import { mkdirSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

const VIEWS = [
  { width: 375, height: 812, isMobile: true, hasTouch: true },
  { width: 768, height: 1024, isMobile: false, hasTouch: true },
  { width: 1280, height: 800, isMobile: false, hasTouch: false },
];
const THEMES = ['light', 'dark'];
const LOAD_TIMEOUT = 30_000; // ms per page load
const MAX_HEIGHT = 4000; // px of a screenshot
const MAX_LIST = 25; // entries per list in the facts
const MAX_FACTS = 20_000; // bytes of the printed facts

const refuse = (msg) => {
  console.error(`devshop-browse: refused: ${msg}`);
  process.exit(1);
};
const cantJudge = (msg) => {
  console.error(`devshop-browse: can't judge: ${msg}`);
  process.exit(2);
};

const origin = process.env.DEVSHOP_BROWSE_ORIGIN;
const project = process.env.DEVSHOP_BROWSE_PROJECT;
const outRoot = process.env.DEVSHOP_BROWSE_OUT;
if (!origin || !project || !outRoot)
  cantJudge('run through the devshop-browse wrapper review.sh writes');

const args = process.argv.slice(2);
if (args.length !== 1)
  refuse('usage: devshop-browse <path> (exactly one path, no flags)');
const path = args[0];
if (!path.startsWith('/'))
  refuse(`'${path}' is not a path on the local run (it must start with /)`);
let target;
try {
  target = new URL(path, origin);
} catch {
  refuse(`'${path}' is not a path`);
}
if (target.origin !== origin)
  refuse(`'${path}' leaves the local run (${target.origin})`);

let chromium;
try {
  // By path, never by search, so a global Playwright (NODE_PATH) can't stand in for the pinned one.
  ({ chromium } = createRequire(join(project, 'package.json'))(
    join(project, 'node_modules', 'playwright')
  ));
} catch (e) {
  cantJudge(
    `the project's Playwright can't be loaded from its node_modules: ${e.message.split('\n')[0]}`
  );
}
let browser;
try {
  browser = await chromium.launch();
} catch (e) {
  cantJudge(
    `the browser can't start (Chromium for the project's Playwright): ${e.message.split('\n')[0]}`
  );
}

// Each call gets its own numbered directory, so two pages never share screenshots.
mkdirSync(outRoot, { recursive: true });
const out = join(outRoot, String(readdirSync(outRoot).length + 1));
mkdirSync(out);

const sameOrigin = (url) => {
  try {
    return new URL(url).origin === origin;
  } catch {
    return false;
  }
};
const facts = {
  page: target.pathname + target.search,
  title: '',
  views: [],
  colours: {}, // per theme, at the first width
  spacing: {}, // per width, in the first theme
  fonts: [],
  console: [],
  failed: [],
  blocked: [],
};
const once = (list, entry) => list.includes(entry) || list.push(entry);

// Measured inside the page: colours and spacing that differ from the browser's defaults for the
// same element (read from a blank iframe), and overflow as the render check defines it.
function inspect() {
  const html = document.documentElement;
  const blank = document.createElement('iframe');
  blank.style.cssText = 'position:absolute;width:0;height:0;border:0';
  document.body.appendChild(blank);
  const bdoc = blank.contentDocument;
  // The same color-scheme, so a dark page's default text colour isn't reported as its own.
  bdoc.documentElement.style.colorScheme = getComputedStyle(html).colorScheme;
  const defaults = new Map();
  const defaultsOf = (tag) => {
    if (!defaults.has(tag)) {
      const el = bdoc.createElement(tag);
      bdoc.body.appendChild(el);
      defaults.set(tag, getComputedStyle(el));
    }
    return defaults.get(tag);
  };
  // The colour as painted, in sRGB hex, through a canvas (the browser does the OKLCH maths).
  const ctx = document
    .createElement('canvas')
    .getContext('2d', { willReadFrequently: true });
  const hex = (css) => {
    ctx.clearRect(0, 0, 1, 1);
    ctx.fillStyle = '#000';
    ctx.fillStyle = css;
    ctx.fillRect(0, 0, 1, 1);
    const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data;
    return a === 0
      ? 'transparent'
      : '#' + [r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('');
  };
  const opacityOf = (el) => {
    let o = 1;
    for (let e = el; e; e = e.parentElement)
      o *= Number(getComputedStyle(e).opacity);
    return o;
  };
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    if (r.width <= 1 && r.height <= 1) return false;
    return getComputedStyle(el).visibility !== 'hidden' && opacityOf(el) > 0;
  };
  const describe = (el) =>
    el.tagName.toLowerCase() +
    (el.id ? `#${el.id}` : '') +
    (el.classList.length ? `.${[...el.classList].join('.')}` : '');
  const colours = new Map();
  const spacing = new Map();
  // A value is counted once per element that uses it, on however many sides.
  let counted = new Set();
  const note = (map, value, el) => {
    if (counted.has(value)) return;
    counted.add(value);
    const e = map.get(value) || { count: 0, first: describe(el) };
    e.count += 1;
    map.set(value, e);
  };
  const sides = ['top', 'right', 'bottom', 'left'];
  for (const el of [html, ...document.body.querySelectorAll('*')]) {
    if (el === blank || (el !== html && !visible(el))) continue;
    counted = new Set();
    const cs = getComputedStyle(el);
    const d = defaultsOf(el.tagName.toLowerCase());
    for (const prop of ['color', 'background-color']) {
      const v = cs.getPropertyValue(prop);
      if (v !== d.getPropertyValue(prop) && hex(v) !== 'transparent')
        note(colours, `${prop}: ${hex(v)} (${v})`, el);
    }
    for (const s of sides) {
      // Only a border that is drawn, and not the browser's own (a default button's).
      const width = cs.getPropertyValue(`border-${s}-width`);
      if (parseFloat(width) <= 0) continue;
      const v = cs.getPropertyValue(`border-${s}-color`);
      const own =
        v !== d.getPropertyValue(`border-${s}-color`) ||
        width !== d.getPropertyValue(`border-${s}-width`) ||
        cs.getPropertyValue(`border-${s}-style`) !==
          d.getPropertyValue(`border-${s}-style`);
      if (own && hex(v) !== 'transparent')
        note(colours, `border-color: ${hex(v)} (${v})`, el);
    }
    for (const prop of [
      ...sides.map((s) => `margin-${s}`),
      ...sides.map((s) => `padding-${s}`),
      'row-gap',
      'column-gap',
    ]) {
      const v = cs.getPropertyValue(prop);
      if (v !== d.getPropertyValue(prop) && v !== 'normal' && v !== '0px')
        note(
          spacing,
          `${prop.replace(/-(top|right|bottom|left)$/, '')}: ${v}`,
          el
        );
    }
  }
  blank.remove();
  const vw = html.clientWidth; // the layout width; a phone view widens innerWidth to fit overflow
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
    )
      if (getComputedStyle(a).overflowX !== 'visible') clipped = true;
    if (!clipped)
      past.push(
        `${describe(el)} spans ${Math.round(r.left)}..${Math.round(r.right)}px`
      );
  }
  const list = (map) =>
    [...map].map(([value, e]) => `${value} ×${e.count} (first: ${e.first})`);
  return {
    scrollsSideways: html.scrollWidth > html.clientWidth + 1,
    pastEdge: past,
    colours: list(colours),
    spacing: list(spacing),
    title: document.title,
  };
}

// Per declared font family, one element that has text of its own: the fonts that drew it.
async function fonts(page) {
  const families = await page.evaluate(() => {
    const seen = new Map();
    for (const el of document.body.querySelectorAll('*')) {
      const own = [...el.childNodes].some(
        (n) => n.nodeType === 3 && n.textContent.trim()
      );
      if (!own) continue;
      const family = getComputedStyle(el).fontFamily;
      if (seen.has(family)) continue;
      el.setAttribute('data-devshop-browse-font', String(seen.size));
      seen.set(family, el.tagName.toLowerCase());
    }
    return [...seen].map(([family, tag]) => ({ family, tag }));
  });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('DOM.enable');
  await cdp.send('CSS.enable');
  const { root } = await cdp.send('DOM.getDocument', { depth: -1 });
  const result = [];
  for (const [i, f] of families.entries()) {
    const { nodeId } = await cdp.send('DOM.querySelector', {
      nodeId: root.nodeId,
      selector: `[data-devshop-browse-font="${i}"]`,
    });
    let drew = [];
    if (nodeId) {
      const r = await cdp.send('CSS.getPlatformFontsForNode', { nodeId });
      drew = r.fonts.map((x) => x.familyName);
    }
    result.push(
      `${f.tag}: declared ${f.family}; drawn with ${drew.join(', ') || 'nothing'}`
    );
  }
  return result;
}

for (const view of VIEWS) {
  for (const theme of THEMES) {
    const context = await browser.newContext({
      viewport: { width: view.width, height: view.height },
      isMobile: view.isMobile,
      hasTouch: view.hasTouch,
      colorScheme: theme,
      serviceWorkers: 'block',
    });
    await context.route('**/*', (route) => {
      const req = route.request();
      if (sameOrigin(req.url())) return route.continue();
      once(
        facts.blocked,
        req.resourceType() === 'font'
          ? `remote font not loaded: ${req.url()}`
          : `${req.resourceType()} ${req.url()}`
      );
      return route.abort('blockedbyclient');
    });
    await context.routeWebSocket(/.*/, (ws) => {
      if (sameOrigin(ws.url())) return ws.connectToServer();
      once(facts.blocked, `websocket ${ws.url()}`);
      return ws.close();
    });
    const page = await context.newPage();
    page.on('console', (m) => {
      if (m.type() === 'error') once(facts.console, m.text());
    });
    page.on('pageerror', (e) => once(facts.console, `uncaught: ${e.message}`));
    page.on('requestfailed', (r) => {
      if (sameOrigin(r.url()))
        once(facts.failed, `${r.url()} (${r.failure()?.errorText})`);
    });
    page.on('response', (r) => {
      if (r.status() >= 400 && sameOrigin(r.url()))
        once(facts.failed, `${r.url()} (HTTP ${r.status()})`);
    });
    let response;
    try {
      response = await page.goto(target.href, {
        waitUntil: 'load',
        timeout: LOAD_TIMEOUT,
      });
    } catch (e) {
      await browser.close();
      cantJudge(`${facts.page} didn't load: ${e.message.split('\n')[0]}`);
    }
    if (!response || response.status() >= 400) {
      await browser.close();
      cantJudge(
        `${facts.page} answered HTTP ${response ? response.status() : 'nothing'}`
      );
    }
    if (!sameOrigin(page.url())) {
      await browser.close();
      cantJudge(`${facts.page} went to another origin (${page.url()})`);
    }
    await page.evaluate(() => document.fonts.ready);
    const shot = join(out, `${view.width}-${theme}.png`);
    const height = await page.evaluate(
      () => document.documentElement.scrollHeight
    );
    await page.screenshot({
      path: shot,
      fullPage: true,
      clip: {
        x: 0,
        y: 0,
        width: view.width,
        height: Math.min(height, MAX_HEIGHT),
      },
    });
    const seen = await page.evaluate(inspect);
    facts.title = seen.title;
    if (view.width === VIEWS[0].width && theme === THEMES[0])
      facts.fonts = await fonts(page);
    if (view.width === VIEWS[0].width) facts.colours[theme] = seen.colours;
    if (theme === THEMES[0]) facts.spacing[view.width] = seen.spacing;
    facts.views.push({
      width: view.width,
      theme,
      screenshot: shot,
      scrollsSideways: seen.scrollsSideways,
      pastEdge: seen.pastEdge.slice(0, MAX_LIST),
    });
    await context.close();
  }
}
await browser.close();

// Every list capped, then halved until the facts fit; a cut is flagged, never silent.
const cap = (n) => {
  for (const k of ['fonts', 'console', 'failed', 'blocked'])
    facts[k] = facts[k].slice(0, n);
  for (const m of [facts.colours, facts.spacing])
    for (const k of Object.keys(m)) m[k] = m[k].slice(0, n);
  for (const v of facts.views) v.pastEdge = v.pastEdge.slice(0, n);
};
const listed = () =>
  [
    ...['fonts', 'console', 'failed', 'blocked'].map((k) => facts[k]),
    ...Object.values(facts.colours),
    ...Object.values(facts.spacing),
    ...facts.views.map((v) => v.pastEdge),
  ].reduce((n, l) => n + l.length, 0);
const before = listed();
cap(MAX_LIST);
let text = JSON.stringify(facts, null, 1);
for (let n = MAX_LIST; text.length > MAX_FACTS && n > 1;) {
  n = Math.floor(n / 2);
  cap(n);
  text = JSON.stringify(facts, null, 1);
}
if (listed() < before) {
  facts.truncated = true;
  text = JSON.stringify(facts, null, 1);
}
for (const v of facts.views) console.log(`screenshot: ${v.screenshot}`);
console.log(text);
