# iOS CI Diagnosis

## Most likely root cause
```One or more Pods declare iOS 9.0; raise to 12+ or set `IPHONEOS_DEPLOYMENT_TARGET` via post_install overrides.```

## Top XCResult issues
- (no structured issues captured from xcresulttool)

## Log stats
- Errors: **1**
- Warnings: **50**
- Deployment target mismatches: **1**

## Pointers
- Full log: `/Users/runner/work/offLLM/offLLM/build/xcodebuild.log`
- Result bundle: `/Users/runner/work/offLLM/offLLM/build/MyOfflineLLMApp.xcresult`