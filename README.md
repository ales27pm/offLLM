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
npm install
npm run codegen
cd ios && xcodegen generate && bundle install && bundle exec pod install --repo-update
```

### Run iOS simulator

```bash
npx react-native run-ios
# unsigned
cd ios && xcodebuild -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

### Run tests

```bash
npm test
```

## Installation & Setup

### Node & npm determinism

- `.npmrc` sets `legacy-peer-deps=true` for consistent installs.
- `package.json` overrides pin `@types/react@^19.1.0`.
- Use `npm run ci:install` in CI; `npm install` locally.

### Codegen

- `npm run codegen` reads [src/specs/](src/specs/) and generates TurboModule headers.
- Re-run after editing specs.

### iOS build

1. `cd ios && xcodegen generate`
2. `bundle install`
3. `bundle exec pod install --repo-update`
4. build via `npx react-native run-ios` or `npm run build:ios` (unsigned)

## Architecture Overview

- React Native 0.81.x with **New Architecture** enabled (TurboModules).
- Swift-first TurboModule pattern: TS spec → Swift class → minimal `.mm` glue.
- JS retrieves modules with `TurboModuleRegistry.getOptional` and falls back to `MLXModule` (iOS) or `LlamaTurboModule` (Android).
- Specs live in [src/specs/](src/specs/); iOS Turbo sources in [ios/MyOfflineLLMApp/Turbo](ios/MyOfflineLLMApp/Turbo).

## Scripts Reference

| Command              | Description                            |
| -------------------- | -------------------------------------- |
| `npm install`        | Local install with peer deps tolerance |
| `npm run ci:install` | Deterministic CI install               |
| `npm run codegen`    | Generate NativeModule headers          |
| `npm test`           | Run Jest suite                         |
| `npm run ios`        | Run iOS simulator                      |
| `npm run build:ios`  | Unsigned Release build for simulator   |

## iOS Unsigned Build (Simulator)

```bash
cd ios && xcodebuild -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

The GitHub Actions workflow [`ios-unsigned.yml`](.github/workflows/ios-unsigned.yml) uploads the unsigned `.ipa` as the `offLLM-unsigned-ipa` artifact.

## Testing & Linting

```bash
npm test
npm run lint
npx prettier . --check
```

## Configuration & Env

- `MEMORY_ENCRYPTION_KEY` – 32‑byte key for local memory encryption. A default key is used in dev; set a real key in production. See [`src/memory/VectorMemory.ts`](src/memory/VectorMemory.ts).
- `MODEL_URL` – remote model to download on first run.
- `MEMORY_ENABLED` / `MEMORY_MAX_MB` – toggle and size for on-device memory.

## Troubleshooting

- **npm ERESOLVE**: installs ignore peers via `.npmrc` or `npm run ci:install`.
- **Pod install failures**: run `bundle exec pod install --repo-update`.
- **Xcode version mismatch**: ensure Xcode 16.x via `xcode-select -switch`.
- **Simulator arch errors**: on Apple Silicon, do not exclude `arm64`; on Intel Macs, set `EXCLUDED_ARCHS=arm64`. Clean Pods and retry: `rm -rf ios/Pods ios/Podfile.lock && cd ios && pod repo update && pod install`.

## Contributing / License

Contributions welcome—see [AGENTS.md](AGENTS.md) for guidelines.
Licensed under the MIT License.
