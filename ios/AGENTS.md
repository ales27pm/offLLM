# iOS Workspace Guidelines

- Keep `MyOfflineLLMApp/Info.plist` populated with the core bundle keys (`CFBundleExecutable`, `CFBundlePackageType`, `CFBundleShortVersionString`, `CFBundleVersion`) so archives pass App Store and sideloader validation. Do not strip them when regenerating the plist from templates.【F:ios/MyOfflineLLMApp/Info.plist†L1-L34】
- Coordinate any future plist migrations with the XcodeGen `project.yml` so the build settings continue to inject `PRODUCT_BUNDLE_IDENTIFIER` and other substitutions correctly.【F:ios/project.yml†L21-L83】
