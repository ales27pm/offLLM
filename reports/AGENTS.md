# Reports & Diagnostics Guide

## Scope & provenance
- Files in this directory are machine-generated artefacts from doctor runs (`REPORT.md`, `report_agent.md`, xcresult pointers). Treat them as read-only snapshots unless you regenerate them via `npm run doctor:ios` or the equivalent CI workflow.【F:REPORT.md†L1-L13】【F:report_agent.md†L1-L10】【F:scripts/dev/doctor.sh†L277-L339】
- The reports power troubleshooting guides and AGENT history. Always refresh them by running the doctor script followed by `npm run reports:commit` instead of editing by hand.【F:package.json†L25-L29】【F:scripts/dev/commit-reports.sh†L52-L77】

## Usage & maintenance
- `REPORT.md` summarises human-readable findings, `report_agent.md` provides condensed next steps for automation, and xcresult JSONs/symlinks live alongside them for deeper dives—preserve this structure so scripts and docs can rely on consistent paths.【F:REPORT.md†L1-L13】【F:report_agent.md†L6-L10】【F:scripts/dev/doctor.sh†L283-L318】
- When pruning old bundles to save space, keep the most recent timestamped folder referenced by CI; the commit helper expects it to exist before copying artefacts.【F:scripts/dev/commit-reports.sh†L22-L77】
- If sensitive data must be redacted, regenerate the reports after sanitising the source logs so downstream tooling stays consistent with the redacted output.【F:scripts/ci/build_report.py†L1-L246】

## Dynamic feedback loop
- Whenever reports surface a new failure mode (e.g., lingering Hermes phases, sandbox toggles), document the fix in the corresponding AGENT living history and leave the annotated report in this directory for traceability.【F:report_agent.md†L6-L10】【F:AGENTS.md†L55-L74】
- Cross-link new documentation or PR summaries back to the relevant `ci-reports/<timestamp>/` folder so future incidents can trace the evidence trail without rerunning the entire build.【F:scripts/dev/doctor.sh†L277-L339】【F:docs/AGENTS.md†L1-L33】

### Living history
- 2025-02 – Recent runs highlighted the need to remove Hermes "Replace Hermes" script phases and disable sandboxing for `[CP]` build steps—leave those notes in place until the underlying pods change.【F:report_agent.md†L6-L10】
- 2025-02 – The absence of xcresult issues in the latest doctor run confirmed the xcresult parser fallback is working; regenerate diagnostics immediately and update tooling guides if that signal changes.【F:REPORT.md†L1-L13】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
