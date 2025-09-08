# AGENTS Instructions

## Mission & Boundaries

- Always run `npm test` before committing changes.
- Prefer minimal, well-commented patches.

## Branch & Commit Policy

- Create feature branches and keep commits atomic.
- Use Conventional Commit style (e.g., `feat(turbo): ...`, `fix(ios): ...`).

## Toolchain & Targets (source of truth)

- **iOS:** deployment target **18.0**
- **Xcode:** **16.2** (iOS 18 SDK)
- **CI runner:** **`macos-15`**
- **Scheme / target:** **`monGARS`**
- **Workspace:** produced by CocoaPods → `ios/monGARS.xcworkspace`

### Do not commit (kept out of VCS)

- `ios/Pods/`, any generated `*.xcworkspace`, `DerivedData/`, and any `*.xcfilelist` artifacts.
- Let CI generate these deterministically.

## Install & Build Playbook

### iOS build

1. **XcodeGen:** `cd ios && xcodegen generate`
2. **Bundler:** `bundle install`
3. **Codegen (if needed):** `npm run codegen`
4. **Pods:** `bundle exec pod install --repo-update`
5. **Doctor:** `./scripts/ios_doctor.sh` (fails early if no `.xcworkspace`)
6. Build locally (sim): `npx react-native run-ios --scheme monGARS`  
   _or_ with xcodebuild:  
   `xcodebuild -workspace ios/monGARS.xcworkspace -scheme monGARS -sdk iphonesimulator -configuration Debug build`

> Unsigned **IPA** is generated in CI by `.github/workflows/ios-unsigned.yml`.  
> Artifacts: `ios-unsigned-ipa` (IPA, zipped .app, `.xcresult`, logs).

### Deterministic CI

```bash
npm run ci:install
```

## Codegen Rules

- Specs live in [src/specs/](src/specs/).
- After changing specs:
  - Run `npm run codegen`.
  - Re-run `bundle exec pod install --repo-update` for iOS.

## TurboModules Rules

- Implement modules Swift-first: TS spec → Swift class → tiny `.mm` glue.
- JS must use `TurboModuleRegistry.getOptional('Name')` with fallback to legacy modules (`MLXModule` iOS / `LlamaTurboModule` Android).
- Keep method names and types aligned with the spec.

## iOS Rules

- Build with Xcode 16.2 (command line tools installed).
- Deployment target stays **18.0** in [`ios/project.yml`](ios/project.yml) and `Podfile` post_install.
- When editing these files, update comments and re-run `bundle exec pod install --repo-update`.
- **Do not enable CocoaPods input/output file lists** with static pods (`:disable_input_output_paths => true` stays). Set `ENABLE_USER_SCRIPT_SANDBOXING` to `NO` in `post_install` for CI stability.
- When editing project.yml or Podfile, ensure no legacy .xcfilelist references or invalid Podfile hooks are reintroduced.
- **CocoaPods version:** CI expects CocoaPods **1.16.2** via the root `Gemfile` and lockfile.
- **Project detection in CI:** the workflow auto-detects `ios/*.xcodeproj` and exports `XCODE_PROJECT_NAME`/`XCODE_PROJECT_PATH`
  (don't hardcode). If no `.xcodeproj` is generated, fix XcodeGen inputs first.
- **Slider pod tip:** Do **not** declare the community Slider manually in the Podfile; rely on autolinking only. Manual lines can
  cause "No podspec found for RNCSlider" due to historical naming (`react-native-slider.podspec`).

## Agent Learning

- Log modifications and build results to track changes and help future iterations avoid regressions.

## Testing & Quality Gates

- Run `npm test` before committing.
- Update or create Jest tests for new code.
- `test -f eslint.config.mjs && npm run lint || echo "lint skipped: no eslint.config.mjs"`
- Run `npm run format:check`.

## Logging & Debugging

- Enable file logging by setting `DEBUG_LOGGING=1` in the env (via `react-native-config`).
- Logs are written under `logs/` in the app's document directory (`logs/app.log`).
- Open the in-app Debug Console (dev builds or `DEBUG_PANEL=1`) to view, copy, share, or clear logs.
- Attach `app.log` when filing issues to aid triage.

## CI Guidance

**Runner:** `macos-15` (matches Xcode 16.x/iOS 18 SDKs).  
**Caches:**

- Node: key `hashFiles('package-lock.json')`
- Pods: key `hashFiles('ios/Podfile.lock')` + `XCODE_VERSION`
- (Opt.) DerivedData for faster PR rebuilds.  
  **Order:** XcodeGen → Bundler → `pod install` → `scripts/ios_doctor.sh` → build.

**Pods I/O lists:** We set `DISABLE_INPUT_OUTPUT_PATHS=YES` in `post_install` to avoid fragile `*.xcfilelist` checks.

## Troubleshooting

- **npm ERESOLVE**: use `npm ci` in CI; locally, try `npm i --legacy-peer-deps` only if necessary.
- **No `.xcworkspace` after Pods**: run the **Doctor**; fix Podfile detection of `.xcodeproj` or re-run XcodeGen.
- **Xcode mismatch**: CI prints versions; pin to Xcode 16.2 locally (`xcode-select -p` to verify).
- **File-list errors**: `DISABLE_INPUT_OUTPUT_PATHS=YES` (already applied in `post_install`).

## PR Checklist

- Local simulator build succeeds.
- `npm test` passes.
- Docs updated for workflow or script changes.
- No secrets committed.

## Rollback Guidance

- Revert doc-only changes with `git revert <commit>`.

## Build Diagnosis & Reports

After each CI run, reports are automatically generated under `reports/`:

- `reports/REPORT.md` — human-readable summary.
- `reports/report_agent.md` — concise agent-friendly prompt.
- `reports/report.json` — structured data (errors, warnings, counts).
- `reports/patches.md` — suggested fixes inferred from the reports.

For local reproduction, `npm run doctor:ios` mirrors the CI flow and writes time-stamped results to `ci-reports/<ts>/`. Use `npm run reports:commit` to copy the latest snapshot to `CI-REPORT.md` and `report_agent.md` at the repo root (and optionally archive under `docs/ci-reports/`).

### Agent Guidelines

- Always consult `report_agent.md` first to quickly understand counts and the first error/warning/xcresult issue.
- If more detail is needed, open `REPORT.md`.
- Use these reports as the authoritative source for diagnosing and fixing build issues.
- Never rely only on raw logs in `.github/workflows` artifacts if a report is available.
- When proposing fixes, cite the corresponding section (e.g., "`Errors` in `REPORT.md`") so humans can trace the context.

### Important

- Do not hand-edit `reports/*`; rely on `npm run codex:analyze`, `npm run codex:fix`, or `npm run doctor:ios` to regenerate.
- If a build fails without generating reports, fallback parsing will still summarize logs, but the agent should note this and recommend rerunning the workflow with report generation enabled.

## Build Doctor Prompt (CI)

When a build fails or has warnings:

1. Read `reports/report_agent.md` first (short, condensed summary).
2. Then open `reports/REPORT.md` (full detail).
3. Finally, check `reports/patches.md` for suggested changes and refine them.

**Rules**

- Propose minimal, safe patches (Podfile hooks, workflow steps).
- If Hermes replacement scripts are present, add/remove phases in both `post_install` and `post_integrate` and add CI guards.
- If deployment target < 12.0 is detected in pods, raise it via `post_install` overrides.
- If “Internal inconsistency error” appears, clean SPM caches, re-resolve packages, and pin versions compatible with Xcode 16.x.
- Output a unified diff (`apply_patch`-ready) when proposing file changes.
