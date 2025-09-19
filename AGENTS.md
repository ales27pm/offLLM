# OffLLM Contributor Guide

## Reality snapshot (keep this current)

- The agent loop lives in `src/core/AgentOrchestrator.js`, which pulls long- and short-term context, builds prompts, executes
  tool calls, and persists results with workflow tracing for observability.【F:src/core/AgentOrchestrator.js†L1-L189】
- Prompt construction, tool parsing, and memory helpers are distributed across `PromptBuilder`, `ToolHandler`, `toolRegistry`,
  `MemoryManager`, and `WorkflowTracer`; changes must preserve their contracts so orchestration stays deterministic.【F:src/core/prompt/PromptBuilder.js†L1-L27】【F:src/core/tools/ToolHandler.js†L1-L158】【F:src/core/tools/ToolRegistry.js†L1-L39】【F:src/core/memory/MemoryManager.js†L1-L37】【F:src/core/workflows/WorkflowTracer.js†L1-L123】
- Platform and advanced integrations hang off `src/architecture` (plugin lifecycle, dependency injection, tool analytics/MCP)
  and `src/services` (LLM runtime, context planning, readability/search, reasoning). Keep those modules aligned with the docs in
  `docs/agent-architecture.md` whenever behaviors change.【F:src/architecture/pluginManager.js†L1-L204】【F:src/architecture/toolSystem.js†L1-L200】【F:src/services/llmService.js†L1-L200】【F:src/services/contextEngineer.js†L1-L200】【F:docs/agent-architecture.md†L3-L56】
- Long-term persistence is handled by the encrypted `VectorMemory` layer plus migrations; it must remain in sync with the
  in-process `MemoryManager` APIs.【F:src/memory/VectorMemory.ts†L1-L168】【F:src/memory/migrations/index.ts†L1-L9】【F:src/core/memory/MemoryManager.js†L1-L34】

## Required workflow

1. Install dependencies with `npm ci` (or `npm install` for quick prototyping) before running scripts defined in `package.json`.
2. Run the baseline quality gates on every change: `npm test`, `npm run lint`, and `npm run format:check`.
3. Touching native code or build tooling? Reproduce the flow in `Steps.md`, and document deviations in your PR so future fixes
   stay deterministic.【F:Steps.md†L1-L108】
4. For iOS/Android changes use the provided helpers (`npm run doctor:ios`, `npm run build:ios`, `npm run build:android`) as
   appropriate.【F:package.json†L6-L28】
5. Keep commits conventional (e.g., `docs:`, `feat:`) and leave the tree clean after every change set.

## Dynamic feedback loop (learning from successes & failures)

- Before starting new work, skim the latest generated reports (`REPORT.md`, `CI-REPORT.md`, `report_agent.md`) to understand
  recent CI noise or resolved blockers.【F:REPORT.md†L1-L13】【F:CI-REPORT.md†L1-L13】【F:report_agent.md†L1-L10】
- When a new failure mode or recovery path emerges, add it to the "Living history" log below with a citation to the log, script,
  or doc that proved the fix. This keeps the guidance adaptive instead of static.
- After a successful mitigation, run `npm run reports:commit` if you update generated diagnostics so history stays auditable.【F:package.json†L25-L29】

### Living history

- Swift 6 concurrency breakages were eliminated by the main-actor patches documented in the native recovery playbook; reuse those
  edits before chasing build ghosts.【F:Steps.md†L12-L28】
- CI bots previously stalled on stray Hermes script phases—purge them and disable sandbox restrictions as captured in the
  condensed build diagnosis before retrying builds.【F:report_agent.md†L6-L10】
- The report commit helper now enforces a clean working tree and can archive entire CI runs, preventing teammates from losing
  diagnostics during joint investigations.【F:scripts/dev/commit-reports.sh†L22-L77】
- Dynamic xcresult parsing chooses when to drop the `--legacy` flag, preserving build insights across Xcode upgrades—keep that
  detection logic intact whenever tooling evolves.【F:tools/xcresult-parser.js†L22-L175】

## Directory map

- `docs/`: canonical architecture reference and operational notes; keep them synchronized with runtime changes.【F:docs/agent-architecture.md†L1-L58】
- `src/core/`: orchestrator, prompt tooling, memory plumbing, workflow tracer, and plugin shim used during runtime.【F:src/core/AgentOrchestrator.js†L1-L189】【F:src/core/workflows/WorkflowTracer.js†L1-L123】
- `src/architecture/`: plugin manager, DI setup, and the advanced tool system (usage analytics, MCP client).【F:src/architecture/pluginManager.js†L1-L204】【F:src/architecture/toolSystem.js†L1-L200】
- `src/services/`: model runtime, context engineering, content enrichment, and reasoning helpers surfaced as tools.【F:src/services/llmService.js†L1-L200】【F:src/services/readabilityService.js†L1-L160】【F:src/services/webSearchService.js†L1-L68】【F:src/services/treeOfThought.js†L1-L191】
- `src/tools/`: platform-specific adapters (iOS implementations, Android stubs, web search) automatically registered by the runtime.【F:src/tools/iosTools.js†L1-L78】【F:src/tools/androidTools.js†L1-L16】【F:src/tools/webSearchTool.js†L1-L86】
- `src/memory/`: encrypted persistence layer plus migrations; align schema updates with `MemoryManager`.【F:src/memory/VectorMemory.ts†L1-L168】【F:src/memory/migrations/index.ts†L1-L9】
<!-- prettier-ignore -->
- `__tests__/`: Jest suites protecting orchestration, tooling, memory, telemetry, and logger behaviour—extend them alongside code changes.【F:__tests__/AGENTS.md†L1-L45】
- `scripts/`: automation for reproducing builds, generating reports, toggling MLX flags, and publishing diagnostics.【F:scripts/AGENTS.md†L1-L63】
- `tools/`: reusable Node helpers (e.g., xcresult parsing) shared by automation entry points.【F:tools/AGENTS.md†L1-L44】
- `reports/` & `Steps.md`: machine-generated diagnostics and validated recovery scripts—treat them as the institutional memory for build and runtime issues.【F:reports/AGENTS.md†L1-L37】【F:Steps.md†L1-L108】

## Testing & verification

<!-- prettier-ignore -->
- Unit/integration coverage lives under `__tests__/`. Extend tests whenever you touch orchestration, memory semantics, plugins,
  or services, and follow the authoring guidance documented in that directory.【F:__tests__/AGENTS.md†L1-L67】
- Always finish with `npm test`, `npm run lint`, and `npm run format:check`; add targeted builds (`npm run build:ios`,
  `npm run build:android`) when platform code is affected.【F:package.json†L6-L28】
- Capture anomalies via `WorkflowTracer` logs or `reports/codex` tooling so the next iteration starts with concrete evidence.【F:src/core/workflows/WorkflowTracer.js†L1-L123】【F:package.json†L22-L24】

Staying disciplined about the workflow above keeps the agent aligned with its documented architecture while letting the guide
evolve as the project learns from fresh signals.
