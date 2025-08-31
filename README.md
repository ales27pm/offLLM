# offLLM

> Offline LLM assistant for mobile devices built with React Native.

![Node](https://img.shields.io/badge/node-%3E=20.19.4-43853d?logo=node.js) ![React Native](https://img.shields.io/badge/React%20Native-0.81.x-61DAFB?logo=react)

## Quick Start

### Prereqs

- Node >= 20.19.4
- Xcode 16.x with command line tools
- Ruby & Bundler
- CocoaPods
- xcodegen

### Install (local)

```bash
npm ci
(cd ios && xcodegen generate && bundle install)
npm run codegen
(cd ios && bundle exec pod install --repo-update)
```

### Run iOS simulator

```bash
npx react-native run-ios
# unsigned
(cd ios && xcodebuild -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO)
```

### Run tests

```bash
npm test
```

## Installation & Setup

### Node & npm determinism

- `.npmrc` sets `legacy-peer-deps=true` only to align React Native's peer deps and avoid `ERESOLVE`.
- `package.json` overrides pin `@types/react: 19.1.0` exactly.
- Use `npm run ci:install` (wraps `npm ci`) in CI and `npm ci` locally for a clean install.

### Codegen

 - `npm run codegen` reads [src/specs/](src/specs/) and generates TurboModule headers under `ios/build/generated/ios`.
 - Re-run after editing specs.

### iOS build

1. `cd ios && xcodegen generate`
2. `bundle install`
3. `npm run codegen`
4. `bundle exec pod install --repo-update`
5. build via `npx react-native run-ios` or `npm run build:ios` (unsigned)

## Architecture Overview

- React Native 0.81.x with **New Architecture** enabled (TurboModules).
- Swift-first TurboModule pattern: TS spec → Swift class → minimal `.mm` glue.
- JS retrieves modules with `TurboModuleRegistry.getOptional` and falls back to `MLXModule` (iOS) or `LlamaTurboModule` (Android).
- Specs live in [src/specs/](src/specs/); iOS Turbo sources in [ios/MyOfflineLLMApp/Turbo](ios/MyOfflineLLMApp/Turbo).

## Scripts Reference

| Command              | Description                     |
| -------------------- | ------------------------------- |
| `npm ci`             | Install deps from lockfile      |
| `npm run ci:install` | CI install wrapper for `npm ci` |
| `npm run codegen`    | Generate Turbo headers          |
| `npm test`           | Run Jest suite                  |
| `npm run lint`       | ESLint                          |
| `npm run ios`        | Run iOS simulator               |

## iOS Unsigned Build (Simulator)

```bash
cd ios && xcodebuild -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

The GitHub Actions workflow [`ios-unsigned.yml`](.github/workflows/ios-unsigned.yml) uploads the unsigned `.ipa` as the `MyOfflineLLMApp-unsigned-ipa` artifact. React Native codegen runs as a required step and will fail fast if generation fails.

## Testing & Linting

```bash
npm test
npm run lint    # if eslint.config.js is present
npm run format:check
```

## Configuration & Env

- `MEMORY_ENCRYPTION_KEY` – 32‑byte key for local memory encryption. Copy [.env.example](.env.example) to `.env` and set a real key. The app throws on production builds if this variable is missing. See [`src/memory/VectorMemory.ts`](src/memory/VectorMemory.ts).
- `MODEL_URL` – remote model to download on first run.
- `MEMORY_ENABLED` / `MEMORY_MAX_MB` – toggle and size for on-device memory.

## Troubleshooting

- **npm ERESOLVE**: installs ignore peers via `.npmrc` or `npm run ci:install`.
- **Pod install failures**: run `bundle exec pod install --repo-update`.
- **Xcode version mismatch**: ensure Xcode 16.x via `xcode-select -switch`.
- **Simulator arch errors**: Apple Silicon users should not exclude `arm64`. Intel hosts can set `EXCLUDED_ARCHS=arm64`. To detect CPU: `uname -m | grep -q x86_64 && export EXCLUDED_ARCHS=arm64`. Clean Pods and retry: `rm -rf ios/Pods ios/Podfile.lock && (cd ios && pod repo update && pod install)`.

## Contributing / License

Contributions welcome—see [AGENTS.md](AGENTS.md) for guidelines.
Licensed under the MIT License.
