# offLLM

> Offline LLM assistant for mobile devices built with React Native.

![Node](https://img.shields.io/badge/node-%3E=18.0.0-43853d?logo=node.js) ![React Native](https://img.shields.io/badge/React%20Native-0.81.x-61DAFB?logo=react)

## Quick Start

### Prereqs

- Node >= 18.0.0
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

### Clean iOS build

```bash
./scripts/clean-build-ios.sh
```

### Failproof unsigned IPA build

```bash
./scripts/build-ios-unsigned.sh
```

## Installation & Setup

### Node & npm determinism

- `.npmrc` sets `legacy-peer-deps=true` only to align React Native's peer deps and avoid `ERESOLVE`.
- `package.json` overrides pin `@types/react: 19.1.0` exactly.
- Use `npm run ci:install` (wraps `npm ci`) in CI and `npm ci` locally for a clean install.

### Codegen

 - `npm run codegen` reads [src/specs/](src/specs/) and generates TurboModule headers under `ios/build/generated/ios`.
 - Re-run after editing specs.
 - CI sets safe defaults for `CODEGEN_OUTPUT_DIR` and `TEMPLATE_SRC_DIR` to avoid path resolution errors.

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
| `./scripts/build-ios-unsigned.sh` | Clean install & unsigned IPA build |

## iOS Unsigned Build (Simulator)

```bash
cd ios && xcodebuild -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

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

## Consent Management

The app uses a privacy-focused consent system (`src/privacy/consents.ts`) to manage permissions for features like camera and location.

- Validates consent keys (`camera`, `location`, `contacts`, `photos`, `microphone`).
- Stores consents with timestamps in AsyncStorage.
- Logs operations for debugging.
- Throws `ConsentError` for invalid keys.

```typescript
import { getConsent, setConsent } from './src/privacy/consents';

async function requestCameraAccess() {
  const consent = await getConsent('camera');
  if (!consent?.value) {
    await setConsent('camera', true);
  }
}
```

## Troubleshooting

- **npm ERESOLVE**: installs ignore peers via `.npmrc` or `npm run ci:install`.
- **Pod install failures**: run `bundle exec pod install --repo-update`.
- **Xcode version mismatch**: ensure Xcode 16.x via `xcode-select -switch`.
 - **Simulator runtime mismatch**: the CI boot step automatically falls back to iOS 18.4 or the newest available runtime if the requested `IOS_SIM_OS` isn't installed.
- **Simulator arch errors**: Apple Silicon users should not exclude `arm64`. Intel hosts can set `EXCLUDED_ARCHS=arm64`. To detect CPU: `uname -m | grep -q x86_64 && export EXCLUDED_ARCHS=arm64`. Clean Pods and retry: `rm -rf ios/Pods ios/Podfile.lock && (cd ios && pod repo update && pod install)`.

## Contributing / License

Contributions welcome—see [AGENTS.md](AGENTS.md) for guidelines.
Licensed under the MIT License.
