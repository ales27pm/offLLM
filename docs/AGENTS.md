# Documentation Guide

## Scope & intent
- `docs/agent-architecture.md` is the canonical explanation of how the orchestrator, plugins, memory, and services interact—update it in lockstep with runtime changes so code and prose stay aligned.【F:docs/agent-architecture.md†L3-L105】
- When you publish operational runbooks (e.g., recovery steps, rollout notes), cross-link the relevant evidence from `ci-reports/<timestamp>/` so future contributors can replay the exact remediation path.【F:scripts/dev/doctor.sh†L277-L339】

## Style & referencing
- Use sentence-case headings, wrap text around ~100 characters, and cite sources with the repository format (`【F:path†Lx-Ly】`) so readers can jump straight to the code that backs each statement.
- Start each document with a short context paragraph summarising why it matters; lean on lists, tables, or diagrams only when they clarify execution paths already described in the text.【F:docs/agent-architecture.md†L3-L58】

## Dynamic knowledge loop
- Before editing, review the latest `report_agent.md`, `REPORT.md`, and `CI-REPORT.md` to absorb new CI heuristics, common failures, and verified fixes; fold relevant lessons into the affected docs.【F:report_agent.md†L1-L10】【F:REPORT.md†L1-L13】【F:CI-REPORT.md†L1-L12】 If the change touches native build recovery, also reconcile it with `Steps.md`.
- After a postmortem or successful mitigation, append a dated summary (`YYYY-MM-DD – …`) to the appropriate document, cite the diagnostic artefact that proved the fix, and mirror the same entry in the living history below so the guidance keeps evolving.
- When diagnostics change, regenerate them via `npm run doctor:ios` followed by `npm run reports:commit` to keep linked evidence fresh and auditable.【F:package.json†L25-L29】【F:scripts/dev/commit-reports.sh†L52-L77】

### Living history
- 2025-02 – The architecture guide now captures the orchestrator → plugin → service flow and must be revisited whenever tool registration or plugin overrides shift.【F:docs/agent-architecture.md†L3-L58】
- 2025-02 – The native recovery playbook documents the Swift 6 concurrency fixes applied to `MLXEvents.swift` and `MLXModule.swift`; reference those annotations before introducing alternative solutions.【F:Steps.md†L12-L28】
- 2025-02 – Generated doctor reports flagged Hermes replacement scripts and sandboxed `[CP]` phases; the linked remediation steps should stay in sync with future CI adjustments.【F:report_agent.md†L6-L10】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
