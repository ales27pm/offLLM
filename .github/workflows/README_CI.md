# CI Workflow: Archive + Unsigned IPA

This workflow archives the app for Generic iOS Device and packages an **unsigned** IPA
by zipping `Payload/*.app`. The IPA is suitable for re-signing later.

- Xcode: 16.4
- Workspace: `ios/monGARS.xcworkspace`
- Scheme: `monGARS`
- Artifacts: `.xcarchive`, unsigned `.ipa`, and `.xcresult`

To get a **signed** IPA instead, replace the packaging step with `xcodebuild -exportArchive`
and provide a valid `ios/export-options.plist` and signing assets.
