# AGENTS Instructions

## Mission & Boundaries

- Always run `npm test` before committing changes.
- Prefer minimal, well-commented patches.

## Branch & Commit Policy

- Create feature branches and keep commits atomic.
- Use Conventional Commit style (e.g., `feat(turbo): ...`, `fix(ios): ...`).

## Install & Build Playbook

- **Local dev**
  ```bash
  npm ci
  (cd ios && xcodegen generate && bundle install)
  npm run codegen
  (cd ios && bundle exec pod install --repo-update)
  ```
- **Deterministic CI**
  ```bash
  npm run ci:install
  ```

## Codegen Rules

- Specs live in [src/specs/](src/specs/).
- After changing specs:
  - Run `npm run codegen`.
  - Re-run `bundle exec pod install` for iOS.

## TurboModules Rules

- Implement modules Swift-first: TS spec → Swift class → tiny `.mm` glue.
- JS must use `TurboModuleRegistry.getOptional('Name')` with fallback to legacy modules (`MLXModule` iOS / `LlamaTurboModule` Android).
- Keep method names and types aligned with the spec.

## iOS Rules

- Build with Xcode 16.x (command line tools installed).
- Deployment target stays **18.0** in [`ios/project.yml`](ios/project.yml), [`ios/MyOfflineLLMApp/project.yml`](ios/MyOfflineLLMApp/project.yml), and `Podfile` post_install.
- When editing these files, update comments and re-run `bundle exec pod install --repo-update`.
- **Do not enable CocoaPods input/output file lists** with static pods (`:disable_input_output_paths => true` stays). Set `ENABLE_USER_SCRIPT_SANDBOXING` to `NO` in `post_install` for CI stability.
- When editing project.yml or Podfile, ensure no legacy .xcfilelist references or invalid Podfile hooks are reintroduced.

## Agent Learning

- Log modifications and build results to track changes and help future iterations avoid regressions.

## Task: Read iOS Build Diagnostic Report and apply fixes

**Goal:** Make the iOS CI build pass reliably.

**Inputs:**

- `ios-build-diagnostics` artifact from the latest CI run
  - `build_report.md`
  - `xcodebuild.log`
  - `MyOfflineLLMApp.xcresult` (if present)

**Instructions:**

1. Open `build_report.md`. Identify the **first fatal error** (not just warnings). Cross-check in `xcodebuild.log` and `xcresult` issues.
2. Classify the failure:
   - Swift build-system/compiler crash
   - Script phase failure
   - Linker issue
   - Codegen/spec generation issue
   - Deployment target / platform mismatch
3. Propose **minimal, concrete fixes**. For each fix:
   - Describe the root cause in one sentence.
   - Provide exact code/config changes (Podfile hooks, SPM pin, Xcode build setting, YAML change).
   - Note any tradeoffs.
4. Update CI to reduce flakiness:
   - Add/adjust cache cleaning or `-jobs 1` retry only when hitting known race/crash signatures.
   - Ensure `-resultBundlePath` and artifact upload steps are present.
5. Output:
   - A patch-style snippet that can be applied directly.
   - A short “why this works” note.

## Testing & Quality Gates

- Run `npm test` before committing.
- Update or create Jest tests for new code.
- `test -f eslint.config.js && npm run lint || echo "lint skipped: no eslint.config.js"`
- Run `npm run format:check`.

## CI Playbook

- `ios-unsigned.yml` workflow: xcodegen → pod install → unsigned simulator build → uploads `offLLM-unsigned-ipa` artifact.
- If CI fails on pods or project generation, try `pod repo update`, `rm -rf ios/Pods`, and rerun xcodegen.

## PR Checklist

- Local simulator build succeeds.
- `npm test` passes.
- Docs updated for workflow or script changes.
- No secrets committed.

## Rollback Guidance

- Revert doc-only changes with `git revert <commit>`.
