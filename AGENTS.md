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
- **Do not enable CocoaPods input/output file lists** with static pods (`:disable_input_output_paths => true` stays). Keep the Hermes "Replace Hermes..." user script neutralized and `ENABLE_USER_SCRIPT_SANDBOXING` set to `NO` in `post_install` for CI stability.

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
