/**
 * ESLint config for the EcoSwap Cloud Functions package (WBS 3.5).
 *
 * Kept intentionally minimal — TypeScript's `strict: true` does the heavy
 * lifting on type safety. ESLint here mostly catches `any` slipping in,
 * unused imports / variables, and obvious style drift.
 *
 * Note: ESLint v8 legacy config (not flat) is used because the lint script
 * still calls `eslint --ext .js,.ts`, and several devDeps (eslint-config-google,
 * older plugin-import) still ship eslintrc-style presets.
 */
module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
    jest: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: "module",
  },
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "plugin:@typescript-eslint/recommended",
  ],
  ignorePatterns: [
    "lib/**/*",
    "generated/**/*",
    "node_modules/**/*",
    "coverage/**/*",
    "jest.config.js",
    ".eslintrc.js",
  ],
  rules: {
    "quotes": ["error", "double", { "avoidEscape": true }],
    "import/no-unresolved": "off",
    "indent": ["error", 2, { "SwitchCase": 1 }],
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/no-unused-vars": [
      "error",
      { "argsIgnorePattern": "^_", "varsIgnorePattern": "^_" },
    ],
  },
  overrides: [
    {
      files: ["test/**/*.ts"],
      rules: {
        // Tests sometimes need `any` to construct minimal CallableRequest
        // shapes; warn on src but allow in tests.
        "@typescript-eslint/no-explicit-any": "off",
      },
    },
  ],
};
