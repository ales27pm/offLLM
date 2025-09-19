# Reports & Diagnostics Guide

## Scope & provenance

- Files in this directory are machine-generated artefacts from iOS build runs (`REPORT.md`, `report_agent.md`, xcresult JSONs).
  Treat them as read-only snapshots unless you regenerate them via the doctor workflow.【F:REPORT.md†L1-L13】【F:report_agent.md†L1-L10】
- The reports power troubleshooting guides and AGENT history. Always refresh them by running `npm run doctor:ios` (or related
  variants) followed by `npm run reports:commit` instead of manual edits.【F:package.json†L25-L29】【F:scripts/dev/commit-reports.sh†L52-L77】

## Usage & maintenance

- `REPORT.md` summarises human-readable findings; `report_agent.md` provides condensed next steps for automation; xcresult JSONs
  live alongside them for deeper dives. Keep this structure intact so scripts and docs can rely on consistent paths.【F:REPORT.md†L1-L13】【F:report_agent.md†L6-L10】
- When pruning old bundles to save space, never delete the most recent timestamped folder referenced by CI—`scripts/dev/commit-
  reports.sh` expects it to exist before copying artefacts.【F:scripts/dev/commit-reports.sh†L22-L43】
- If you must scrub sensitive paths, regenerate the reports after sanitising the source logs so downstream tooling stays in sync
  with the redacted data.【F:scripts/ci/build_report.py†L183-L200】

## Adaptive feedback loop

- Whenever reports surface a new failure mode (e.g., missing Hermes phase, sandbox toggles), document the fix in the
  corresponding AGENT living history and leave the annotated report in this directory for traceability.【F:report_agent.md†L6-L10】【F:AGENTS.md†L29-L55】
- Cross-link new guidance from `docs/` or PR descriptions back to these artefacts so future incidents can trace the evidence
  trail without rerunning the entire build.【F:docs/AGENTS.md†L1-L25】

### Living history

- Recent runs highlighted the need to remove legacy Hermes script phases and disable sandboxing for `[CP]` build steps—retain
  those notes until the underlying pods are upgraded so contributors do not repeat the fix.【F:report_agent.md†L6-L10】
- The absence of xcresult issues in the latest report confirmed that the xcresult parser fallback is working; if that changes,
  regenerate diagnostics immediately and update the tooling guides.【F:REPORT.md†L1-L13】
