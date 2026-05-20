// PostCSS config — wires Tailwind v4's PostCSS plugin. Tailwind v4 has no
// JS config; tokens live in `app/globals.css` under `@theme`.

export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
