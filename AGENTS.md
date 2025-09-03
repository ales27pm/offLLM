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

## CI Repair Prompt (ingests compact digest)

Read `build/ios-ci-report/report_agent.md`. Based on the listed root cause, errors, warnings, and recommendations:

1. Propose a minimal patch to fix the CI build deterministically.
2. If Hermes “Replace Hermes” script phases appear, add/remediate Podfile `post_install`/`post_integrate` scrubbing.
3. Ensure xcodebuild invocations use `-parallelizeTargets NO -jobs 1` on CI.
4. Reduce warning noise (raise pod `IPHONEOS_DEPLOYMENT_TARGET` to 18.0; fix header symlink script phases).
   Output unified diffs only.

## CI Report Sources (Git-backed)

Primary (latest): `ci-reports` branch → `reports/ios/latest/REPORT.md`
Per-run report: `ci-reports` branch → `reports/ios/<RUN_ID>/REPORT.md`

When diagnosing iOS CI issues, read the latest digest first:

- `reports/ios/latest/report_agent.md` (compact)
- `reports/ios/latest/REPORT.md` (full)

If needed, read `xcodebuild.log` and `xcresult.json` in the same folder.
