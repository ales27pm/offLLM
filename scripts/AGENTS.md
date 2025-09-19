# Automation Scripts Guide

## Scope & structure
- `scripts/dev/doctor.sh` reproduces CI locally: it loads `.env` defaults, runs xcodegen/pod install, strips Hermes replacement phases, archives builds, and generates heuristics plus reports under `ci-reports/<timestamp>` for follow-up analysis.【F:scripts/dev/doctor.sh†L1-L339】
- CI-facing helpers live in `scripts/ci/`, where `build_report.py` parses `xcodebuild.log` and `.xcresult` bundles, retries the `--legacy` flag when necessary, and emits both human and agent reports without failing the workflow.【F:scripts/ci/build_report.py†L1-L246】
- Platform toggles stay in dedicated entry points: `scripts/ios_doctor.sh` resets DerivedData/workspaces for CI chaining, while `scripts/detect_mlx_symbols.sh` scans Swift interfaces and writes the single-source-of-truth `ios/Config/Auto/MLXFlags.xcconfig`.【F:scripts/ios_doctor.sh†L1-L39】【F:scripts/detect_mlx_symbols.sh†L1-L47】
- Publishing helpers such as `scripts/dev/commit-reports.sh` guard against dirty worktrees, copy the latest reports into canonical paths, and optionally archive the entire run for historical context.【F:scripts/dev/commit-reports.sh†L22-L77】

## Authoring guidance
- Default new Bash scripts to `set -euo pipefail`, surface descriptive errors, and centralise shared logic instead of duplicating it—`doctor.sh` already exposes helpers for xcresult probing, log scraping, and heuristics reuse.【F:scripts/dev/doctor.sh†L9-L318】
- Prefer shelling out through Node/Python utilities in `tools/` (e.g., `xcresult-parser.js`, `util.mjs`) when you need reusable parsing or subprocess orchestration; extend them rather than baking new heuristics into multiple scripts.【F:tools/xcresult-parser.js†L1-L175】【F:tools/util.mjs†L1-L27】
- Document new environment toggles and diagnostics expectations directly in the script headers so contributors understand how to reproduce CI behaviour locally.【F:scripts/dev/doctor.sh†L1-L44】

## Operational workflow
- Run `npm run doctor:ios` (or its simulator/fast variants) to capture a fresh CI reproduction, then inspect `ci-reports/<timestamp>/` for logs, xcresult links, and heuristics before deciding on remediation steps.【F:package.json†L25-L27】【F:scripts/dev/doctor.sh†L1-L339】
- After updating diagnostics, publish them with `npm run reports:commit`, which enforces a clean tree, copies `REPORT.md`/`report_agent.md`, and can archive the full timestamped directory for posterity.【F:package.json†L28-L29】【F:scripts/dev/commit-reports.sh†L52-L77】
- Keep `scripts/` and the documentation guides in sync—new automation should be mirrored in `docs/` and the root contributor guide so the workflow diagrams remain truthful.【F:docs/AGENTS.md†L1-L33】【F:AGENTS.md†L1-L74】

## Dynamic feedback loop
- When a script mitigates a failure (e.g., toggling MLX flags, archiving new diagnostics, stripping Hermes phases), summarise the outcome in `REPORT.md`/`report_agent.md`, cite the timestamp in the living history below, and update any dependent docs to preserve the institutional knowledge.【F:report_agent.md†L6-L10】【F:REPORT.md†L1-L13】
- If xcresult schemas or build heuristics change, update the shared tooling (`tools/xcresult-parser.js`, `scripts/ci/build_report.py`) first, then flow the lessons into `doctor.sh` and the relevant guides so every layer stays aligned.【F:tools/xcresult-parser.js†L1-L175】【F:scripts/ci/build_report.py†L1-L200】

### Living history
- 2025-02 – `ios_doctor.sh` now fails fast when CocoaPods workspaces are missing and exports the workspace path for downstream jobs—preserve that discovery loop when editing pod-install logic.【F:scripts/ios_doctor.sh†L1-L39】
- 2025-02 – The doctor workflow strips Hermes "Replace Hermes" phases, flags sandboxed `[CP]` scripts, and logs deployment-target drift, which prevented opaque Xcode errors during CI triage; keep those heuristics intact when refactoring.【F:scripts/dev/doctor.sh†L233-L318】【F:report_agent.md†L6-L10】
- 2025-02 – `commit-reports.sh` enforces clean working trees and can archive entire runs, stopping teams from losing diagnostics during shared investigations—do not relax those guards without a replacement plan.【F:scripts/dev/commit-reports.sh†L22-L77】
