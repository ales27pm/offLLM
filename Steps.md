# Native Build Recovery Playbook

This workflow documents the deterministic sequence we now follow when React Native/Hermes versions drift or when Swift 6 concurrency checks break the iOS build. It mirrors the verified steps from the latest debugging session so engineers can reproduce the clean environment locally or in CI.

## 0. Prerequisites

- **Xcode:** 16.4 (`sudo xcode-select -s "/Applications/Xcode_16.4.app/Contents/Developer"`)
- **Swift toolchain:** bundled with Xcode 16.4 (Swift 6.1.2)
- **Ruby:** 3.2 with Bundler (install via `brew install ruby` and `gem install bundler`)
- **CocoaPods:** managed through Bundler (`bundle install` in the repo root)
- **Node:** 20.x with npm 10.x (`nvm use 20 && npm install -g npm@latest`)

## 1. Clean JavaScript dependencies

```bash
rm -rf node_modules package-lock.json
npm ci
```

The clean install guarantees that `node_modules/react-native` resolves to the version recorded in `package.json` (currently `0.81.4`).

## 2. Regenerate iOS projects (if applicable)

```bash
cd ios
xcodegen generate || true
cd ..
```

`xcodegen` is idempotent; if the workspace is already committed this step simply refreshes derived project files.

## 3. Reset iOS Pods and lockfile

```bash
cd ios
rm -rf Pods Podfile.lock
bundle install
bundle exec pod repo update
bundle exec pod install --repo-update
cd ..
```

By deleting the lockfile and the Pods directory we ensure CocoaPods re-resolves React Native + Hermes using the same versions npm installed. The Bundler wrapper keeps pod plugins aligned with the Ruby toolchain in `Gemfile`.

## 4. Purge Xcode caches

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
```

This clears stale module caches that previously triggered `fatal error: module 'RCTDeprecation' in AST file ...`.

## 5. Swift 6 concurrency fixes

The Swift patches are already committed, but keep this checklist handy when auditing changes:

- `MLXEvents.sharedStorage` remains annotated with `nonisolated(unsafe)` and is updated in `init`/`deinit` on the main actor.
- `MLXModule.stream` takes an `@Sendable` token callback and uses a regular `Task` rather than `Task.detached` when streaming.

If either file changes in the future, re-run these adjustments before shipping.

## 6. Verify React Native and Hermes parity

```bash
python3 scripts/verify-ios-rn-versions.py
```

Expected output (with RN 0.81.4):

```
react-native (package.json): 0.81.4
React-* pods (Podfile.lock): ['0.81.4']
hermes-engine pods (Podfile.lock): ['0.81.4']
```

A non-zero exit code signals drift—repeat Step 3 if that happens.

## 7. iOS build (unsigned)

```bash
cd ios
xcodebuild \
  -workspace monGARS.xcworkspace \
  -scheme monGARS \
  -configuration Release \
  -sdk iphoneos \
  -UseModernBuildSystem=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  clean build
cd ..
```

Using `xcodebuild` avoids the simulator instability that `npx react-native run-ios` introduces on CI agents.

## 8. Optional: Archive and produce an unsigned IPA

```bash
cd ios
ARCHIVE_PATH=build/monGARS.xcarchive
APP_NAME=monGARS

xcodebuild \
  -workspace "$APP_NAME.xcworkspace" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -sdk iphoneos \
  -UseModernBuildSystem=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive -archivePath "$ARCHIVE_PATH"

mkdir -p build/Payload
rm -rf build/Payload/*
cp -R "$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" build/Payload/
(cd build && zip -r "${APP_NAME}-unsigned.ipa" Payload >/dev/null)
cd ..
```

The resulting IPA is unsigned—use it for artifact inspection only.

## 9. Android sanity check (optional)

```bash
./android/gradlew :app:assembleDebug
```

Running the Android build after fixing iOS prevents regressions in shared JavaScript modules that both platforms consume.

---

Following this playbook keeps React Native, Hermes, and Swift concurrency configurations synchronized between JavaScript and native layers. Update this file whenever we evolve the workflow so `Steps.md` remains the single source of truth.
