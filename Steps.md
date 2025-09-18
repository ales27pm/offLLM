# Native Build Recovery Playbook

This workflow documents the deterministic sequence we now follow when React Native/Hermes versions drift or when Swift 6 concurrency checks break the iOS build. It mirrors the verified steps from the latest debugging session so engineers can reproduce the clean environment locally or in CI.

## 0. Prerequisites

- **Xcode 16.4** selected: `sudo xcode-select -s "/Applications/Xcode_16.4.app/Contents/Developer"`
- **Swift 6.1.2** (bundled with Xcode 16.4)
- **Ruby 3.2+ with CocoaPods 1.15+**: `gem install cocoapods -v ">= 1.15.0"`
- **Node 20+ / npm 10+**

## 1. Patch Swift files (only if not already committed)

```bash
# MLXEvents.swift
nonisolated(unsafe) private static weak var sharedStorage: MLXEvents?
nonisolated(unsafe) static var shared: MLXEvents? { sharedStorage }
override init() { super.init(); MLXEvents.sharedStorage = self }
deinit { if MLXEvents.sharedStorage === self { MLXEvents.sharedStorage = nil } }

# MLXModule.swift
func stream(... onToken: @escaping @Sendable (String) -> Void) async throws {
  Task { [weak self] in ... }
}
```

These annotations keep Swift 6 strict-concurrency checks satisfied by ensuring the shared emitter is main-actor scoped and the streaming callback is safe to cross actors.

## 2. Reset RN/Hermes Pods

```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install --repo-update
cd ..
```

Removing the lockfile forces CocoaPods to resolve React Native and Hermes against the versions currently installed in `node_modules` (e.g., RN 0.81.4).

## 3. Purge Xcode caches

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
```

This clears stale module caches that caused the `fatal error: module 'RCTDeprecation' in AST file ...` crash.

## 4. Deterministic iOS build (unsigned)

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

Using `xcodebuild` avoids the simulator flakiness we see with `npx react-native run-ios`, making the process reproducible on CI and local machines.

## 5. Verify RN/Hermes versions

```bash
python3 scripts/verify-ios-rn-versions.py
```

You should see matching versions for `react-native`, all `React-*` pods, and `hermes-engine` (e.g., `0.81.4`). If the script exits non-zero, repeat Step 2.

## 6. Optional: Archive & produce an unsigned IPA

```bash
cd ios
ARCHIVE_PATH=build/monGARS.xcarchive
APP_NAME=monGARS

xcodebuild \
  -workspace monGARS.xcworkspace \
  -scheme monGARS \
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

The unsigned IPA is suitable for artifact inspection and size checks but cannot be installed on devices without signing.

## 7. Optional: Deployment target sanity check

If `platform :ios, '18.0'` in your `Podfile` is higher than required, lower it (for example to `16.0`) and repeat Steps 2–5 to regenerate the lockfile and rebuild.

---

Following this playbook keeps React Native, Hermes, and Swift concurrency aligned with the committed workflow so future recoveries remain deterministic.
