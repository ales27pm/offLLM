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

You are a build doctor. Read the artifact **ci_diagnosis.md** produced by CI (and optionally xcresult.json if needed). Then:

1. Identify the primary build-breaking error(s). Be concise.
2. Propose concrete fixes that can be applied as code/config changes (Podfile, project.yml, Xcode settings, workflow YAML, or source).
3. Output your answer as a set of patch blocks the user can apply directly:
   - For YAML or Podfile changes, use fenced blocks starting with ```patch and unified diff format.
   - For source files, also use unified diffs.
4. Keep the response under ~6000 tokens. If findings are too long, summarize and link to file paths/sections.

**Inputs**:

- `ios/build/ci_diagnosis.md` (compact report from CI)
- Optional: `ios/build/xcresult.json` for exact issue contexts

**Heuristics**:

- If you see “Internal inconsistency error: never received target ended message”, first try build-system stability flags (disable target parallelization, set SWIFT_WORKER_THREADS=1) and consider pinning swift-transformers if needed.
- If deployment target warnings (< iOS 12) appear in Pods sub-targets, add a `post_install` block to enforce a consistent minimum.
- Avoid changing user code unless necessary; prefer Podfile/project/workflow adjustments.

**Deliverables**:

- A short diagnosis paragraph.
- One or more patch blocks implementing the fixes.
- A “What changed & why” bullet list tied to each patch.

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
