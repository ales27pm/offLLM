# Automation Scripts Guide

## Scope & structure

- Shell, Python, and Node scripts under this directory reproduce CI builds, surface diagnostics, and toggle iOS build flags.
  Keep entry points idempotent so they can be called repeatedly by GitHub Actions and local doctor sessions.【F:scripts/dev/doctor.sh†L1-L55】【F:scripts/ci/build_report.py†L1-L43】
- Top-level Bash helpers (`ios_doctor.sh`, `detect_mlx_symbols.sh`, packaging scripts) expect macOS tooling but load `.env`
  overrides automatically. Preserve that bootstrapping so contributors do not have to export variables manually.【F:scripts/ios_doctor.sh†L1-L40】【F:scripts/detect_mlx_symbols.sh†L1-L47】
- CI-specific routines live in `scripts/ci/`; they parse logs, enforce MLX bridge sanity, and emit build summaries that power
  `REPORT.md` and `report_agent.md`. Keep the command-line interface stable for workflow consumers.【F:scripts/ci/build_report.py†L1-L200】

## Authoring guidance

- Default to `set -euo pipefail` in Bash scripts and bail with descriptive errors. Existing helpers guard clean worktrees,
  capture xcresult compatibility, and prune stale build artefacts—mirror their defensive checks when you extend automation.【F:scripts/dev/commit-reports.sh†L17-L77】【F:scripts/ios_doctor.sh†L1-L39】【F:scripts/ci/build_report.py†L99-L153】
- Centralise repeated logic rather than duplicating: use `scripts/dev/doctor.sh` for local iOS reproduction, then layer
  specialised wrappers via environment variables (e.g., `NO_INSTALL`, `DESTINATION`). Document new toggles directly in the
  script header and in any downstream docs so discoverability stays high.【F:scripts/dev/doctor.sh†L1-L58】
- When adding log parsers or xcresult tooling, prefer Node/Python modules in this tree so they can share utilities (`tools/
xcresult-parser.js`, `scripts/codex/lib`). Keep exports pure and deterministic to ease unit testing.【F:scripts/ci/build_report.py†L99-L200】【F:tools/xcresult-parser.js†L1-L185】

## Operational workflow

- Run `npm run doctor:ios` (and its variants) to reproduce CI locally; the command wraps `scripts/dev/doctor.sh` and persists
  artefacts under `ci-reports/<timestamp>`. Use `npm run reports:commit` afterwards to publish updated diagnostics.【F:package.json†L25-L29】【F:scripts/dev/commit-reports.sh†L52-L77】
- For manual investigations, `scripts/ios_doctor.sh` clears DerivedData and exports the discovered workspace path to
  `$GITHUB_ENV` when running in CI; reuse that behaviour for any new step that feeds subsequent jobs.【F:scripts/ios_doctor.sh†L20-L40】
- MLX feature detection writes `ios/Config/Auto/MLXFlags.xcconfig`; keep that file the sole source of conditional compilation so
  native targets stay reproducible between machines.【F:scripts/detect_mlx_symbols.sh†L6-L47】

## Adaptive feedback loop

- When a script mitigates a failure (e.g., toggling MLX flags, archiving new diagnostics), log the rationale in `REPORT.md` or
  `report_agent.md` and summarise the lesson in the living history below. That ensures future responders understand why the
  automation exists.【F:REPORT.md†L1-L13】【F:report_agent.md†L6-L10】
- Keep the guides in `docs/` and the root `AGENTS.md` synced with new automation so workflow diagrams and contributor checklists
  reflect the updated process.【F:AGENTS.md†L1-L74】【F:docs/agent-architecture.md†L3-L25】

### Living history

- `ios_doctor.sh` now fails fast when CocoaPods workspaces are missing, stopping CI from producing opaque Xcode errors—retain the
  workspace discovery loop when altering pod install logic.【F:scripts/ios_doctor.sh†L25-L40】
- The report commit helper refuses to run on a dirty tree and optionally archives entire CI runs, preventing accidental loss of
  diagnostics when multiple contributors iterate on the same failure.【F:scripts/dev/commit-reports.sh†L22-L77】
- Automatic MLX symbol scanning writes compile-time flags that gate Swift features; without it, release builds shipped missing
  factory loaders. Do not regress the detection heuristics or xcconfig output path.【F:scripts/detect_mlx_symbols.sh†L6-L47】
