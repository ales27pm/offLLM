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

## iOS Build Doctor (CI Triage)

**Artifacts to read first:**

- `build/ci_diagnosis.md` (≤8K chars): compact summary from the latest run.

**Instructions:**

1. Read `ci_diagnosis.md` and list the top 3 concrete failures with file/target names if present.
2. For each, propose the smallest code/config change required (Podfile, workflow flags, or specific source files).
3. Output diffs in unified format. Keep changes minimal and safe for CI.
4. Do **not** paste entire logs. Keep the response under 300 lines.

## CI Report Sources (Git-backed)

Primary (latest): `ci-reports` branch → `reports/ios/latest/ci_diagnosis.md`
Per-run report: `ci-reports` branch → `reports/ios/<RUN_ID>/ci_diagnosis.md`

If needed, read `xcodebuild.log` and `.xcresult` in the same folder.
