import js from '@eslint/js';
import jsdoc from 'eslint-plugin-jsdoc';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    plugins: { jsdoc },
    rules: {
      // Code quality rules only — Prettier owns all formatting
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/no-explicit-any': 'warn',
      'jsdoc/require-jsdoc': [
        'warn',
        {
          require: { FunctionDeclaration: true },
          contexts: [
            'ExportNamedDeclaration > VariableDeclaration > VariableDeclarator > ArrowFunctionExpression',
          ],
          checkConstructors: false,
        },
      ],
    },
  },
  {
    // .claude/skills/gstack/** is vendored from the gstack repo (see commit
    // 6c240b9). It lints clean upstream against gstack's own rules but trips
    // devshop's stricter empty-block-statement / no-require-imports rules.
    // Treat vendored code as third-party — upstream owns its lint config.
    ignores: [
      '**/node_modules/**',
      '**/.next/**',
      '**/dist/**',
      '.claude/skills/gstack/**',
    ],
  }
);
