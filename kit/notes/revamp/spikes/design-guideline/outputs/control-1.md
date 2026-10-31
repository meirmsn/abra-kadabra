# Control run 1 (main's `build` § 2 and guidelines), 2026-10-31, verbatim

FILES READ, IN ORDER:

1. /root/scratch-design-guideline/main/runtime/guidelines/README.md
2. /root/scratch-design-guideline/main/runtime/guidelines/ui.md
3. /root/scratch-design-guideline/control-1/DESIGN.md
4. /root/scratch-design-guideline/control-1/index.html
5. /root/scratch-design-guideline/control-1/base.css
6. /root/scratch-design-guideline/control-1/theme.js
   -- first edit --
7. /root/scratch-design-guideline/control-1/base.css (re-read by the post-edit token verification script)
8. /root/scratch-design-guideline/control-1/index.html (re-read by the post-edit token verification script)

DIFF:

```diff
diff --git a/base.css b/base.css
index 14f0423..b98bd7f 100644
--- a/base.css
+++ b/base.css
@@ -28,6 +28,8 @@
   --border: oklch(0.9 0.01 255);
   --input: oklch(0.82 0.012 255);
   --ring: oklch(0.6 0.17 262);
+  --highlight: oklch(0.62 0.16 48); /* copper: the one figure a section is about (DESIGN.md) */
+  --highlight-foreground: oklch(0.99 0.005 60);
   --shadow:
     0 1px 2px oklch(0.2 0.02 260 / 6%), 0 1px 3px oklch(0.2 0.02 260 / 8%);

@@ -36,6 +38,7 @@
     system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial,
     sans-serif;
   --font-mono: ui-monospace, 'SF Mono', Menlo, Consolas, monospace;
+  --font-display: 'Instrument Serif', Georgia, 'Times New Roman', serif;
   --space-1: 0.25rem;
   --space-2: 0.5rem;
   --space-3: 0.75rem;
@@ -69,6 +72,8 @@
   --border: oklch(0.3 0.02 260);
   --input: oklch(0.4 0.02 260);
   --ring: oklch(0.68 0.14 262);
+  --highlight: oklch(0.76 0.13 55);
+  --highlight-foreground: oklch(0.2 0.03 50);
   --shadow: 0 1px 2px oklch(0 0 0 / 30%);
 }

@@ -95,6 +100,8 @@
     --border: oklch(0.3 0.02 260);
     --input: oklch(0.4 0.02 260);
     --ring: oklch(0.68 0.14 262);
+    --highlight: oklch(0.76 0.13 55);
+    --highlight-foreground: oklch(0.2 0.03 50);
     --shadow: 0 1px 2px oklch(0 0 0 / 30%);
   }
 }
@@ -296,6 +303,24 @@ code {
   gap: var(--space-2);
 }

+/* Monthly totals: a display-face title and one figure that matters, in copper (DESIGN.md). */
+.totals > h2 {
+  font-family: var(--font-display);
+  font-weight: 400;
+  font-size: 1.5rem;
+  letter-spacing: -0.01em;
+}
+
+.figure {
+  margin: 0;
+  font-family: var(--font-display);
+  font-size: clamp(2.5rem, 2rem + 2vw, 3.5rem); /* large text: the copper reads at 3:1+ in light */
+  font-variant-numeric: tabular-nums;
+  letter-spacing: -0.01em;
+  line-height: 1.1;
+  color: var(--highlight);
+}
+
 /* ---- Controls: the L-72 contract, set once here ---- */

 button,
diff --git a/index.html b/index.html
index b529faa..b761875 100644
--- a/index.html
+++ b/index.html
@@ -45,6 +45,15 @@
           </article>
         </section>

+        <section class="card totals" aria-labelledby="totals-title">
+          <h2 id="totals-title">Monthly totals</h2>
+          <p>
+            Everything the household ticked off this month, across all lists,
+            counted once.
+          </p>
+          <p class="figure">1,284</p>
+        </section>
+
         <section id="tasks" aria-labelledby="tasks-title">
           <h2 id="tasks-title">Tasks</h2>
           <ul class="list">
```
