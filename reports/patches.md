# Suggested Fixes (Codex CLI)

This file is generated from `REPORT.md` + `report_agent.md` heuristics.

## Context (agent summary)

## Build Diagnosis (Condensed)

- Errors: 0, Warnings: 0
- Signals: No singular dominant failure; inspect errors & warnings.

### Next actions (high-level)
- Remove '[Hermes] Replace Hermes' script phases (Pods + user projects).
- Ensure ENABLE_USER_SCRIPT_SANDBOXING=NO and disable IO paths for [CP] scripts if using static pods.
- Force IPHONEOS_DEPLOYMENT_TARGET >= 12.0 in post_install for old pods.
- Clean SPM caches & re-resolve packages if you see 'Internal inconsistency error'.

## Proposed changes

_No specific suggestions inferred from report content._
