# Documentation Guide

## Scope & intent

- `docs/agent-architecture.md` is the single source of truth for how orchestration, plugins, tools, and persistence interact; update it whenever runtime wiring changes so code and prose stay aligned.【F:docs/agent-architecture.md†L3-L58】
- When you introduce operational playbooks (e.g., build recoveries, rollout guides), cross-link back to the generated diagnostics in `reports/` so future contributors can replay the fix path.【F:REPORT.md†L1-L13】【F:Steps.md†L1-L108】

## Style & structure

- Use sentence-case headings, wrap at ~100 characters, and employ the repository citation format (`【F:path†Lx-Ly】`) to anchor explanations to concrete code locations.
- Start each document with a succinct context paragraph summarizing what changed or why the guidance matters; reinforce deep dives with tables or diagrams only when they clarify execution paths.

## Living knowledge loop

- Before editing, skim the latest `report_agent.md` or CI artifacts to incorporate newly discovered constraints or resolutions into the docs.【F:report_agent.md†L1-L9】
- After a postmortem or successful recovery, append a short dated note in the relevant doc describing the trigger and fix, referencing the log or script that validated it. This keeps the documentation adaptive instead of static checklists.

### Living history

- Architecture docs already capture the orchestrator → plugin → service relationships; keep verifying those narratives when modules like `LLMService` or `ToolRegistry` evolve.【F:docs/agent-architecture.md†L3-L25】【F:src/services/llmService.js†L1-L187】【F:src/architecture/toolSystem.js†L1-L127】
- The native build recovery playbook feeds this directory—continue recording validated remediation sequences there so the next incident has a tested path forward.【F:Steps.md†L1-L108】

Document what happened, why it succeeded or failed, and where the evidence lives so the knowledge base keeps learning alongside the codebase.
