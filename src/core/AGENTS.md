# Core Runtime Guide

## Runtime pillars
- `AgentOrchestrator.run` orchestrates the full loop: retrieve vector and conversational context, build initial and final prompts, call the LLM, parse tool directives, execute registered tools, and persist interactions with `WorkflowTracer` instrumentation. Preserve this single-pass flow so tracing and memory stay coherent.【F:src/core/AgentOrchestrator.js†L27-L189】【F:src/core/workflows/WorkflowTracer.js†L24-L115】
- `PromptBuilder` enumerates every registered tool (name, description, parameter schema) and stitches context into the prompt. Keep output deterministic so identical inputs produce identical strings for caching and tests.【F:src/core/prompt/PromptBuilder.js†L1-L27】
- `ToolHandler` parses `TOOL_CALL:` directives, validates arguments, executes tools with tracer hooks, and records structured `{ role: "tool" }` payloads. Extend `_parseArgs` rather than bypassing it so malformed payloads are rejected instead of silently ignored.【F:src/core/tools/ToolHandler.js†L6-L158】
- The runtime auto-registers platform tools via `toolRegistry.autoRegister`, selecting iOS or Android exports at startup; keep tool objects exposing `{ name, execute }` so discovery remains automatic.【F:src/core/tools/ToolRegistry.js†L5-L39】

## Memory & retrieval
- `MemoryManager` wires together the vector indexer, retriever (with sparse-attention reranking), and conversation history buffer. Constructor overrides make it easy to inject fakes during testing—keep those optional parameters intact.【F:src/core/memory/MemoryManager.js†L8-L34】
- Long-term persistence relies on the encrypted `VectorMemory` layer and forward-only migrations. Schema changes must stay aligned with the in-process APIs to avoid drift between runtime retrieval and disk storage.【F:src/memory/VectorMemory.ts†L45-L136】【F:src/memory/migrations/index.ts†L1-L8】

## Execution hygiene
- Any change to orchestration, tool semantics, or memory must ship with test coverage in `__tests__/` and documentation updates in `docs/agent-architecture.md` so expectations remain explicit.【F:__tests__/AGENTS.md†L1-L37】【F:docs/agent-architecture.md†L3-L105】
- Finish each change by running the baseline quality gates (`npm test`, `npm run lint`, `npm run format:check`) and any targeted builds for native changes.【F:package.json†L10-L18】 Use `WorkflowTracer` output when diagnosing regressions and keep the key insights in the living history below.【F:src/core/workflows/WorkflowTracer.js†L24-L115】

## Dynamic feedback loop
- Record new tool parsing bugs, orchestration regressions, or memory anomalies in your PR notes (or `Steps.md`) and echo the distilled lesson in this guide so future contributors start with context; the legacy markdown reports are now archival only.【F:Steps.md†L1-L108】
- When you add or rename tools, update both the runtime registry and the platform-specific exports, then mirror the change in the documentation and tests to avoid drift.【F:src/core/tools/ToolRegistry.js†L5-L39】【F:src/tools/iosTools.js†L1-L200】【F:src/tools/androidTools.js†L1-L15】

### Living history
- 2025-02 – Structured tracing around `executeTools` exposed mis-registered tool names; maintain the tracer hand-offs when refactoring to preserve that signal.【F:src/core/AgentOrchestrator.js†L125-L183】
- 2025-02 – `_parseArgs` validation prevented silent prompt corruption during prompt experiments—keep new tool syntaxes compatible with the existing parser or expand it with focused tests before rollout.【F:src/core/tools/ToolHandler.js†L31-L109】【F:__tests__/toolHandler.test.js†L27-L90】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
