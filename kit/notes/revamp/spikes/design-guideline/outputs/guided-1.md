# Guided run 1 (this change's `build` § 2 and guidelines), 2026-10-31, verbatim

FILES READ, IN ORDER:

1. /root/scratch-design-guideline/guided-1/ (directory listing; no CLAUDE.md, no docs/ — project CLAUDE.md and docs map do not exist)
2. /root/scratch-design-guideline/guided-1/DESIGN.md
3. /home/user/abra-kadabra/runtime/guidelines/ (directory listing)
4. /home/user/abra-kadabra/runtime/guidelines/design.md
5. /home/user/abra-kadabra/runtime/guidelines/ui.md
6. /root/scratch-design-guideline/guided-1/index.html
7. /root/scratch-design-guideline/guided-1/base.css
8. /root/scratch-design-guideline/guided-1/theme.js
9. /home/user/abra-kadabra/runtime/templates/ui/ (directory listing)
10. /home/user/abra-kadabra/runtime/templates/ui/tokens-check.mjs
11. /home/user/abra-kadabra/runtime/templates/ui/render-check.mjs (contrast section, lines 195-235, via grep/sed)
    -- first edit --
12. /home/user/abra-kadabra/runtime/templates/ui/render-check.mjs (grep for how it picks its browser)
13. /home/user/abra-kadabra/node_modules/playwright-core/browsers.json and /opt/node-tools/node_modules/playwright-core/browsers.json (grep for the installed Chromium revision)

(Checks run after the edit: tokens-check on base.css + index.html: "ok, 34 tokens, 9 contrast pairs"; render-check at 375/768/1280 px light and dark: "ok", six screenshots in /tmp/rc-out. Notes: `--highlight-foreground` from DESIGN.md was deliberately not added to the theme, since copper on its foreground is 3.76:1 in light and tokens-check would pair and fail them; the figure is set at 2.5rem so copper on the light ground (3.76:1) passes as large text (3:1). The section sits directly after the Summary grid, before Tasks, which is before the form card. No Instrument Serif font is self-hosted in the project; the stack's fallbacks draw it, as DESIGN.md says.)

DIFF:

```diff
diff --git a/base.css b/base.css
index 14f0423..8595f8e 100644
--- a/base.css
+++ b/base.css
@@ -28,6 +28,7 @@
   --border: oklch(0.9 0.01 255);
   --input: oklch(0.82 0.012 255);
   --ring: oklch(0.6 0.17 262);
+  --highlight: oklch(0.62 0.16 48); /* copper: the one figure a section is about (DESIGN.md) */
   --shadow:
     0 1px 2px oklch(0.2 0.02 260 / 6%), 0 1px 3px oklch(0.2 0.02 260 / 8%);

@@ -36,6 +37,7 @@
     system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial,
     sans-serif;
   --font-mono: ui-monospace, 'SF Mono', Menlo, Consolas, monospace;
+  --font-display: 'Instrument Serif', Georgia, 'Times New Roman', serif;
   --space-1: 0.25rem;
   --space-2: 0.5rem;
   --space-3: 0.75rem;
@@ -69,6 +71,7 @@
   --border: oklch(0.3 0.02 260);
   --input: oklch(0.4 0.02 260);
   --ring: oklch(0.68 0.14 262);
+  --highlight: oklch(0.76 0.13 55);
   --shadow: 0 1px 2px oklch(0 0 0 / 30%);
 }

@@ -95,6 +98,7 @@
     --border: oklch(0.3 0.02 260);
     --input: oklch(0.4 0.02 260);
     --ring: oklch(0.68 0.14 262);
+    --highlight: oklch(0.76 0.13 55);
     --shadow: 0 1px 2px oklch(0 0 0 / 30%);
   }
 }
@@ -296,6 +300,27 @@ code {
   gap: var(--space-2);
 }

+/* Monthly totals: section title in the display face; the figure in copper, the highlight DESIGN.md
+   reserves for the one figure a section is about. Large type so copper on the light ground passes
+   as large text. */
+
+.display {
+  font-family: var(--font-display);
+  font-weight: 400;
+  letter-spacing: -0.01em;
+}
+
+.figure {
+  margin: 0;
+  font-family: var(--font-display);
+  font-weight: 400;
+  font-size: 2.5rem;
+  line-height: 1.1;
+  letter-spacing: -0.01em;
+  font-variant-numeric: tabular-nums;
+  color: var(--highlight);
+}
+
 /* ---- Controls: the L-72 contract, set once here ---- */

 button,
diff --git a/index.html b/index.html
index b529faa..457305f 100644
--- a/index.html
+++ b/index.html
@@ -45,6 +45,12 @@
           </article>
         </section>

+        <section class="card" aria-labelledby="totals-title">
+          <h2 id="totals-title" class="display">Monthly totals</h2>
+          <p>Across every list, the household closed more items this month than in any month since spring.</p>
+          <p class="figure">1,284</p>
+        </section>
+
         <section id="tasks" aria-labelledby="tasks-title">
           <h2 id="tasks-title">Tasks</h2>
           <ul class="list">
```
