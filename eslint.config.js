import js from "@eslint/js";
import reactPlugin from "eslint-plugin-react";
import globals from "globals";
import tsParser from "@typescript-eslint/parser";

export default [
  {
    ignores: [
      "coverage/",
      "ios/build/",
      "ios/Pods/",
      "android/app/build/",
      "android/.gradle/",
      "android/.idea/",
      "node_modules/",
      "dist/",
      "build/",
    ],
  },
  js.configs.recommended,
  {
    files: ["**/*.{js,jsx,ts,tsx}"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module",
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
      globals: {
        ...globals.node,
        ...globals.browser,
        ...globals.jest,
        console: "readonly",
        URL: "readonly",
        setTimeout: "readonly",
        TextEncoder: "readonly",
      },
    },
    plugins: {
      react: reactPlugin,
    },
    rules: {
      "no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "react/jsx-uses-vars": "error",
      "react/react-in-jsx-scope": "off",
      "react/prop-types": "off",
    },
    settings: {
      react: { version: "detect" },
    },
  },
  {
    files: ["**/*.{ts,tsx}"],
    languageOptions: {
      parser: tsParser,
    },
  },
];
