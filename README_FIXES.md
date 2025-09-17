# iOS Unsigned Build Fix Pack

Included files:

- `.github/workflows/ios-unsigned.yml` — unified simulator + device (archive) workflow
- `ios/Podfile` — disables CocoaPods input/output path analysis unconditionally and adds `install! 'cocoapods', :disable_input_output_paths => true`

Drop these into the repository, commit, and push.
