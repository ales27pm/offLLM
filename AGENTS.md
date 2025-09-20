# OffLLM Contributor Guide

## Current architecture snapshot (keep this accurate)
- `AgentOrchestrator.run` drives the end-to-end loop: it retrieves long- and short-term context, builds an initial prompt, calls the LLM, parses any `TOOL_CALL` markers, optionally executes tools, and persists the final exchange with workflow tracing so every run is auditable.【F:src/core/AgentOrchestrator.js†L27-L189】
- `PromptBuilder` enumerates the currently registered tools and weaves their metadata plus retrieved context into the model prompt; keep its output deterministic so caching and tests stay stable.【F:src/core/prompt/PromptBuilder.js†L1-L27】
- `ToolHandler` validates structured arguments, executes registered tools with tracer hooks, and records structured `{ role: "tool" }` payloads so follow-up prompts can inject results safely.【F:src/core/tools/ToolHandler.js†L6-L158】
- Memory orchestration combines the in-process `MemoryManager` (vector indexer, retriever, history) with the encrypted `VectorMemory` persistence layer and forward-only migrations—changes to one side must stay in lockstep with the other.【F:src/core/memory/MemoryManager.js†L8-L33】【F:src/memory/VectorMemory.ts†L45-L136】【F:src/memory/migrations/index.ts†L1-L8】
- `LLMService` owns model download/bridging, plugin enablement, KV-cache limits, embeddings, and adaptive quantization scheduling; it routes generation through the plugin manager when overrides are active.【F:src/services/llmService.js†L14-L350】
- Higher-level planning lives in `ContextEngineer`, which enforces vector-store contracts, sparse-attention fallbacks, and device-aware token budgeting before prompts are built.【F:src/services/contextEngineer.js†L182-L444】
- Advanced plugins and analytics are surfaced through `src/architecture`, whose tool registry tracks usage statistics and exposes the MCP client for remote tool execution.【F:src/architecture/toolSystem.js†L1-L392】
- `WorkflowTracer` instruments every step with consistent logging so regressions can be replayed without guessing at the control flow.【F:src/core/workflows/WorkflowTracer.js†L24-L116】

## Working agreements
- Install dependencies with `npm ci` (or `npm install` for quick spikes) before running the scripts defined in `package.json` so the native bridges and tooling stay in sync.【F:package.json†L6-L29】
- Always finish a change by running `npm test`, `npm run lint`, and `npm run format:check`; add the native build helpers (`npm run build:ios`, `npm run build:android`) whenever you touch platform code or Xcode projects.【F:package.json†L10-L18】
- Reproduce native flows with the doctor script: `npm run doctor:ios` wraps `scripts/dev/doctor.sh`, mirrors CI heuristics, and drops reports under `ci-reports/<timestamp>` for auditing.【F:package.json†L25-L27】【F:scripts/dev/doctor.sh†L1-L318】 Document any deviations from the baseline Steps playbook inside your PR so the deterministic recovery path in `Steps.md` stays trustworthy.【F:Steps.md†L1-L108】
- Keep commits conventional (`docs:`, `feat:`, `fix:`…) and leave the tree clean after each change set; `scripts/dev/commit-reports.sh` will refuse to publish diagnostics if the worktree is dirty unless you explicitly override it.【F:scripts/dev/commit-reports.sh†L22-L77】

## Adaptive workflow (make the guide learn)
- Before starting new work, skim the latest `CI-REPORT.md`, `REPORT.md`, and `report_agent.md` so you inherit the most recent CI signals, heuristics, and remediation notes.【F:CI-REPORT.md†L1-L12】【F:REPORT.md†L1-L13】【F:report_agent.md†L1-L10】 If the investigation touches Swift, React Native, or Hermes upgrades, cross-check the validated instructions in `Steps.md`.
- When you discover a new failure mode or a repeatable fix, add a dated entry (`YYYY-MM-DD – summary …`) to the living history below and cite the log, script, or doc that proved the resolution. Update the scoped AGENT in the affected directory at the same time so guidance stays coherent across the repo.
- After refreshing generated diagnostics, run `npm run reports:commit` (or call `scripts/dev/commit-reports.sh` directly) to publish `CI-REPORT.md` and `report_agent.md`, archiving the timestamped folder if the change is historically significant.【F:package.json†L25-L29】【F:scripts/dev/commit-reports.sh†L52-L77】

## Directory handoff
- `docs/` hosts the canonical architecture narrative—update it alongside runtime changes and keep citations pointing to concrete code.【F:docs/agent-architecture.md†L3-L105】
- `__tests__/` houses Jest coverage for orchestration, tools, memory, telemetry, and services; extend or add suites when you change their contracts.【F:__tests__/toolHandler.test.js†L5-L90】【F:__tests__/vectorMemory.test.js†L8-L43】【F:__tests__/workflowTracer.test.js†L24-L56】【F:__tests__/llmService.test.js†L6-L48】
- `scripts/` contains automation for reproducing CI, parsing xcresult bundles, toggling MLX flags, and publishing diagnostics—prefer extending the existing helpers over cloning logic.【F:scripts/dev/doctor.sh†L1-L318】【F:scripts/detect_mlx_symbols.sh†L1-L47】【F:scripts/ci/build_report.py†L1-L246】【F:scripts/dev/commit-reports.sh†L22-L77】
- `tools/` provides reusable Node utilities such as the xcresult parser and shell wrapper that the scripts consume.【F:tools/xcresult-parser.js†L1-L175】【F:tools/util.mjs†L1-L27】
- `reports/` stores machine-generated diagnostics; treat them as read-only snapshots unless you regenerate them via the doctor workflow.【F:REPORT.md†L1-L13】【F:report_agent.md†L1-L10】
- `src/core/`, `src/architecture/`, `src/services/`, `src/memory/`, and `src/tools/` host the runtime, plugin system, services, persistent storage, and tool exports respectively—touching any of them usually means updating the paired docs and tests referenced above.【F:src/core/AgentOrchestrator.js†L27-L189】【F:src/architecture/pluginManager.js†L1-L227】【F:src/services/llmService.js†L14-L350】【F:src/memory/VectorMemory.ts†L45-L136】【F:src/tools/iosTools.js†L1-L200】

## Quality gates & evidence
- Commit only after the baseline checks pass locally (`npm test`, `npm run lint`, `npm run format:check`).【F:package.json†L10-L14】 Capture additional artefacts (doctor reports, workflow traces) when debugging so the next iteration starts from evidence instead of guesswork.【F:scripts/dev/doctor.sh†L277-L339】【F:src/core/workflows/WorkflowTracer.js†L24-L115】

## Living history (append new entries with citations)
- 2025-02 – Swift 6 strict-concurrency failures were neutralised by the annotated patches captured in the native recovery playbook; reuse those edits before chasing new build ghosts.【F:Steps.md†L12-L28】
- 2025-02 – CI runs stalled on leftover Hermes "Replace Hermes" phases and sandboxed `[CP]` scripts; the doctor workflow now strips those phases and flags deployment-target drift automatically, so keep the heuristics intact when updating build automation.【F:report_agent.md†L6-L10】【F:scripts/dev/doctor.sh†L233-L318】
- 2025-02 – `commit-reports.sh` enforces clean worktrees and can archive full report folders, preventing teams from losing diagnostics during joint investigations—do not remove those guards when extending the helper.【F:scripts/dev/commit-reports.sh†L22-L77】
- 2025-09-20 – Sideloading builds failed when the Info.plist missed `CFBundleExecutable`; populate the core bundle metadata (`CFBundleExecutable`, version strings, package type) so export tools accept the archive.【F:ios/MyOfflineLLMApp/Info.plist†L1-L44】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
