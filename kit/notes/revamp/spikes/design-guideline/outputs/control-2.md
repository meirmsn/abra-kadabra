# Control run 2 (main's `build` § 2 and guidelines), 2026-10-31, verbatim

FILES READ, IN ORDER:

1. /root/scratch-design-guideline/control-2/DESIGN.md
2. /root/scratch-design-guideline/main/runtime/guidelines/README.md
3. /root/scratch-design-guideline/main/runtime/guidelines/ui.md
4. /root/scratch-design-guideline/control-2/index.html
5. /root/scratch-design-guideline/control-2/base.css
6. /root/scratch-design-guideline/control-2/theme.js
   -- first edit --
7. /root/scratch-design-guideline/control-2/base.css (re-read by an ad-hoc node token check after editing)
8. /root/scratch-design-guideline/control-2/index.html (re-read by the same check)

DIFF:

```diff
diff --git a/base.css b/base.css
index 14f0423..ce2ae94 100644
--- a/base.css
+++ b/base.css
@@ -28,6 +28,7 @@
   --border: oklch(0.9 0.01 255);
   --input: oklch(0.82 0.012 255);
   --ring: oklch(0.6 0.17 262);
+  --highlight: oklch(0.62 0.16 48); /* the one figure a section is about (DESIGN.md) */
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
@@ -296,6 +300,29 @@ code {
   gap: var(--space-2);
 }

+/* The display voice (DESIGN.md: headings in the serif face, regular, slightly tightened). */
+.display {
+  font-family: var(--font-display);
+  font-weight: 400;
+  letter-spacing: -0.01em;
+}
+
+h2.display {
+  font-size: 1.5rem;
+}
+
+/* The one figure a section is about: large, in copper, nowhere else (DESIGN.md § Colors). */
+.figure {
+  margin: 0;
+  font-family: var(--font-display);
+  font-size: clamp(2.25rem, 1.75rem + 2vw, 3rem);
+  font-weight: 400;
+  line-height: 1.1;
+  letter-spacing: -0.01em;
+  font-variant-numeric: tabular-nums;
+  color: var(--highlight);
+}
+
 /* ---- Controls: the L-72 contract, set once here ---- */

 button,
diff --git a/index.html b/index.html
index b529faa..475422c 100644
--- a/index.html
+++ b/index.html
@@ -45,6 +45,15 @@
           </article>
         </section>

+        <section class="card" aria-labelledby="totals-title">
+          <h2 id="totals-title" class="display">Monthly totals</h2>
+          <p>
+            Tasks finished across both lists since the ledger began in
+            January, counted at the end of each month.
+          </p>
+          <p class="figure"><data value="1284">1,284</data></p>
+        </section>
+
         <section id="tasks" aria-labelledby="tasks-title">
           <h2 id="tasks-title">Tasks</h2>
           <ul class="list">
```
