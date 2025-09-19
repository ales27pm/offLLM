# Build Tooling Guide

## Scope & responsibilities

- Utilities in this directory back the CI doctor and report generators. They expose small ESM modules (`util.mjs`,
  `xcresult-parser.js`) that scripts import to inspect xcresult bundles and normalise subprocess execution.【F:tools/util.mjs†L1-L27】【F:tools/xcresult-parser.js†L1-L185】
- Keep modules side-effect free so they can be required both from CLI entry points and unit tests. Any executable behaviour
  should be gated behind the `process.argv` check at the bottom of the file, mirroring the xcresult parser’s pattern.【F:tools/xcresult-parser.js†L133-L185】

## Authoring guidance

- Extend `util.mjs` instead of scattering subprocess wrappers; `sh` already captures stdout/stderr/error state and returns
  structured results for downstream heuristics.【F:tools/util.mjs†L3-L17】
- When parsing xcresult output, funnel extraction through `getValues` so you respect the nested `_values` arrays in Apple’s
  plist-style JSON. Document any new traversal helpers with comments explaining the data shape.【F:tools/util.mjs†L19-L27】【F:tools/xcresult-parser.js†L159-L173】
- Treat legacy Xcode compatibility as a first-class requirement: keep the logic that probes `xcresulttool --help` and reorders
  command attempts based on support for `--legacy` so older runners still succeed.【F:tools/xcresult-parser.js†L22-L131】

## Operational workflow

- Scripts under `scripts/` should import these helpers rather than duplicating parsing or shell logic. If a script needs new
  capabilities (e.g., additional xcresult issue fields), add them here, write focused unit coverage, and update dependent
  automation in one commit for traceability.【F:scripts/ci/build_report.py†L99-L200】【F:tools/xcresult-parser.js†L133-L185】
- Keep ESM exports stable—the modules run under Node 18+ using native ES modules. Prefer named exports and avoid CommonJS
  interop to prevent bundler regressions.【F:tools/xcresult-parser.js†L1-L185】

## Adaptive feedback loop

- Record parsing edge cases or xcresult schema changes in `REPORT.md`/`report_agent.md` when they inform tooling updates, and
  mirror the distilled lesson in the living history below so future contributors know why heuristics exist.【F:REPORT.md†L1-L13】【F:report_agent.md†L6-L10】
- When new diagnostics consumers appear (e.g., dashboards, CI comments), document how they ingest parser output and update the
  dependent script guides accordingly.【F:scripts/AGENTS.md†L1-L54】

### Living history

- The `xcresult` parser’s legacy flag detection prevented CI regressions when Xcode removed `--legacy` support on certain
  runners—preserve the retry ordering and failure selection logic when refactoring.【F:tools/xcresult-parser.js†L22-L131】
- Structured shell wrappers in `util.mjs` surfaced non-zero exit codes during earlier investigations; reuse them to avoid silent
  failures when adding new tooling.【F:tools/util.mjs†L3-L17】
