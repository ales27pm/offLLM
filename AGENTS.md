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

## Task: Fix iOS build from CI diagnosis

You are a build doctor. Read the compact diagnosis report produced by CI and apply fixes.

**Input report:** `build/ci_diagnosis.md`
(Guaranteed to be <= 180 KB.)

**Your tasks:**

1. Summarize the top root causes and the exact files/lines they affect.
2. Propose minimal, well-commented patches (use `apply_patch` style) to:
   - Fix any invalid `xcodebuild` flags or arguments.
   - Address errors found in `.xcresult` (e.g., missing headers, bad search paths, failing script phases).
   - Silence high-entropy warnings that break CI signal (e.g., too-low pod deployment targets).
3. Re-run the reasoning to confirm the fixes would eliminate the errors called out in the report.

**Constraints:**

- Keep patches as small as possible, with inline comments explaining _why_.
- Do not introduce new tools unless they are already available in the workflow environment.
- If a fix is risky, propose it behind a guarded step or with a clear rollback note.

**Output:**

- A short summary of causes.
- A single `apply_patch` block with all necessary changes.

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

**Inputs available as CI artifacts:**

- `build/ci_diagnosis.md` (≤8K chars) — compact summary generated from the latest build.
- `build/xcodebuild.log`, `build/*.xcresult` (full artifacts if you need detail).

**Your task:**

1. Read `ci_diagnosis.md` and identify the _most likely_ root cause in 1–3 bullets.
2. Propose concrete repository changes to fix it. Prefer small, surgical edits:
   - For missing `react/bridging/*` headers, ensure the app's Debug/Release xcconfig files `#include` the Pods-generated configs and (if needed) add `ReactCommon` / `React-Codegen` header search paths.
3. Output your answer as:
   - **Patches**: each with path and a minimal diff block.
   - **Rationale**: 1–2 sentences per patch.
4. Keep the total output under 300 lines. If uncertain, propose the smallest change that surfaces richer errors next run.

**Don’ts:** Don’t paste the entire log. Don’t propose sweeping refactors. Aim for the next green build.
