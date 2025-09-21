# Documentation Guide

## Scope & intent
- `docs/agent-architecture.md` is the canonical explanation of how the orchestrator, plugins, memory, and services interact—update it in lockstep with runtime changes so code and prose stay aligned.【F:docs/agent-architecture.md†L3-L105】
- When you publish operational runbooks (e.g., recovery steps, rollout notes), link to the logs or console captures attached to the relevant PR so future contributors can replay the exact remediation path; the legacy `ci-reports/<timestamp>/` directory is no longer populated automatically.【F:Steps.md†L1-L108】

## Style & referencing
- Use sentence-case headings, wrap text around ~100 characters, and cite sources with the repository format (`【F:path†Lx-Ly】`) so readers can jump straight to the code that backs each statement.
- Start each document with a short context paragraph summarising why it matters; lean on lists, tables, or diagrams only when they clarify execution paths already described in the text.【F:docs/agent-architecture.md†L3-L58】

## Dynamic knowledge loop
- Before editing, review `Steps.md`, recent PRs, and the latest architecture notes to absorb new CI heuristics, common failures, and verified fixes; the archived `report_agent.md`/`REPORT.md`/`CI-REPORT.md` files are optional background if you need historical context.【F:Steps.md†L1-L108】【F:docs/agent-architecture.md†L3-L105】 If the change touches native build recovery, also reconcile it with `Steps.md`.
- After a postmortem or successful mitigation, append a dated summary (`YYYY-MM-DD – …`) to the appropriate document, cite the diagnostic artefact that proved the fix, and mirror the same entry in the living history below so the guidance keeps evolving.
- When diagnostics change, capture the new evidence (logs, screenshots, xcresult snippets) and link them directly from the doc or PR; there is no automated report publishing step to run anymore.【F:scripts/dev/doctor.sh†L277-L339】

### Living history
- 2025-02 – The architecture guide now captures the orchestrator → plugin → service flow and must be revisited whenever tool registration or plugin overrides shift.【F:docs/agent-architecture.md†L3-L58】
- 2025-02 – The native recovery playbook documents the Swift 6 concurrency fixes applied to `MLXEvents.swift` and `MLXModule.swift`; reference those annotations before introducing alternative solutions.【F:Steps.md†L12-L28】
- 2025-02 – Legacy doctor captures flagged Hermes replacement scripts and sandboxed `[CP]` phases; the linked remediation steps should stay in sync with future CI adjustments.【F:report_agent.md†L6-L10】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
