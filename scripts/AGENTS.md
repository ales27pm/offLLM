# Automation Scripts Guide

## Scope & structure
- `scripts/dev/doctor.sh` reproduces CI locally: it loads `.env` defaults, runs xcodegen/pod install, strips Hermes replacement phases, archives builds, and prints heuristics that previously fed the legacy `ci-reports/<timestamp>` artefacts.【F:scripts/dev/doctor.sh†L1-L339】 Capture anything relevant from its output when you need to share diagnostics.
- CI-facing helpers live in `scripts/ci/`, where `build_report.py` parses `xcodebuild.log` and `.xcresult` bundles, retries the `--legacy` flag when necessary, and surfaces human-readable diagnostics without failing the workflow.【F:scripts/ci/build_report.py†L1-L246】
- Platform toggles stay in dedicated entry points: `scripts/ios_doctor.sh` resets DerivedData/workspaces for CI chaining, while `scripts/detect_mlx_symbols.sh` scans Swift interfaces and writes the single-source-of-truth `ios/Config/Auto/MLXFlags.xcconfig`.【F:scripts/ios_doctor.sh†L1-L39】【F:scripts/detect_mlx_symbols.sh†L1-L47】
- The legacy helper `scripts/dev/commit-reports.sh` still exists for teams that archive diagnostics manually; it enforces a clean worktree before copying artefacts if you choose to use it.【F:scripts/dev/commit-reports.sh†L22-L77】

## Authoring guidance
- Default new Bash scripts to `set -euo pipefail`, surface descriptive errors, and centralise shared logic instead of duplicating it—`doctor.sh` already exposes helpers for xcresult probing, log scraping, and heuristics reuse.【F:scripts/dev/doctor.sh†L9-L318】
- Prefer shelling out through Node/Python utilities in `tools/` (e.g., `xcresult-parser.js`, `util.mjs`) when you need reusable parsing or subprocess orchestration; extend them rather than baking new heuristics into multiple scripts.【F:tools/xcresult-parser.js†L1-L175】【F:tools/util.mjs†L1-L27】
- Document new environment toggles and diagnostics expectations directly in the script headers so contributors understand how to reproduce CI behaviour locally.【F:scripts/dev/doctor.sh†L1-L44】

## Operational workflow
- Run `npm run doctor:ios` (or its simulator/fast variants) to capture a fresh CI reproduction, then review the emitted logs and xcresult summaries before deciding on remediation steps; if you need to share findings, upload the artefacts manually because `ci-reports/<timestamp>/` is no longer populated automatically.【F:package.json†L25-L27】【F:scripts/dev/doctor.sh†L1-L339】
- After updating diagnostics, document the outcome in your PR or the relevant guide—there is no automated `npm run reports:commit` step anymore.【F:Steps.md†L1-L108】
- Keep `scripts/` and the documentation guides in sync—new automation should be mirrored in `docs/` and the root contributor guide so the workflow diagrams remain truthful.【F:docs/AGENTS.md†L1-L33】【F:AGENTS.md†L1-L74】

## Dynamic feedback loop
- When a script mitigates a failure (e.g., toggling MLX flags or stripping Hermes phases), record the reproduction and fix in this guide’s living history and update any dependent docs so the institutional knowledge persists.【F:scripts/dev/doctor.sh†L233-L318】【F:Steps.md†L1-L108】
- If xcresult schemas or build heuristics change, update the shared tooling (`tools/xcresult-parser.js`, `scripts/ci/build_report.py`) first, then flow the lessons into `doctor.sh` and the relevant guides so every layer stays aligned.【F:tools/xcresult-parser.js†L1-L175】【F:scripts/ci/build_report.py†L1-L200】

### Living history
- 2025-02 – `ios_doctor.sh` now fails fast when CocoaPods workspaces are missing and exports the workspace path for downstream jobs—preserve that discovery loop when editing pod-install logic.【F:scripts/ios_doctor.sh†L1-L39】
- 2025-02 – The doctor workflow strips Hermes "Replace Hermes" phases, flags sandboxed `[CP]` scripts, and logs deployment-target drift, which prevented opaque Xcode errors during CI triage; keep those heuristics intact when refactoring.【F:scripts/dev/doctor.sh†L233-L318】
- 2025-02 – `commit-reports.sh` enforced clean working trees when teams archived diagnostics through the legacy pipeline; retain the guard rails for anyone who still exports snapshots manually.【F:scripts/dev/commit-reports.sh†L22-L77】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
