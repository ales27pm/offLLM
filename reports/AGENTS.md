# Reports & Diagnostics Guide

## Scope & provenance
- Files in this directory are legacy artefacts from earlier doctor runs (`REPORT.md`, `report_agent.md`, xcresult pointers). Treat them as read-only snapshots; new investigations typically attach logs directly to PRs instead of regenerating these markdown summaries.【F:REPORT.md†L1-L13】【F:report_agent.md†L1-L10】
- The folder remains for historical reference. If you do regenerate diagnostics, note the context in your PR rather than relying on the retired `npm run reports:commit` workflow.【F:scripts/dev/doctor.sh†L277-L339】

## Usage & maintenance
- `REPORT.md` summarises human-readable findings and `report_agent.md` captures condensed automation notes from the last time the pipeline ran. Preserve the structure if you add new archival snapshots so scripts that still read these files continue to function.【F:REPORT.md†L1-L13】【F:report_agent.md†L6-L10】
- When pruning old bundles to save space, leave at least one recent snapshot referenced by documentation; if you create a fresh one manually, document the location in `Steps.md` or the relevant guide.
- If sensitive data must be redacted, regenerate the artefact from sanitized logs before committing it so any downstream tooling stays consistent.【F:scripts/ci/build_report.py†L1-L246】

## Dynamic feedback loop
- When a legacy report highlights a failure mode (e.g., lingering Hermes phases, sandbox toggles), echo the fix in the relevant AGENT living history so future contributors know the outcome even without regenerating markdown snapshots.【F:AGENTS.md†L55-L74】
- When sharing new diagnostics, link to uploaded logs or console captures in your PR instead of pointing to `ci-reports/<timestamp>/`; that folder is no longer populated automatically.【F:scripts/dev/doctor.sh†L277-L339】【F:Steps.md†L1-L108】

### Living history
- 2025-02 – Legacy doctor runs highlighted the need to remove Hermes "Replace Hermes" script phases and disable sandboxing for `[CP]` build steps—leave those notes in place until the underlying pods change.【F:report_agent.md†L6-L10】
- 2025-02 – The absence of xcresult issues in the last captured report confirmed the xcresult parser fallback was working; if that changes, capture fresh logs and update tooling guides accordingly.【F:REPORT.md†L1-L13】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
