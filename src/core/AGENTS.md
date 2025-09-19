# Core Runtime Guide

## Runtime pillars

- `AgentOrchestrator.run` orchestrates the entire loop: retrieve vector and chat context, build prompts, execute model passes, route tool calls, and persist results with `WorkflowTracer` instrumentation. Preserve this single-pass flow so tracing and memory state remain coherent.【F:src/core/AgentOrchestrator.js†L37-L189】【F:src/core/workflows/WorkflowTracer.js†L1-L123】
- `PromptBuilder` enumerates every registered tool and stitches context into the model prompt. Keep output deterministic so the same inputs yield the same string—caching and tests depend on it.【F:src/core/prompt/PromptBuilder.js†L1-L27】
- `ToolHandler` is responsible for parsing `TOOL_CALL:` directives, strict argument validation, execution, and error surfacing. Extend `_parseArgs` rather than bypassing it so malformed payloads are rejected instead of propagating undefined behavior.【F:src/core/tools/ToolHandler.js†L12-L158】
- `toolRegistry` auto-registers iOS/Android adapters at startup. Whenever you add or rename native tools, ensure the exports expose `{ name, execute }` to stay discoverable.【F:src/core/tools/ToolRegistry.js†L1-L39】

## Memory & retrieval

- `MemoryManager` wires together the vector indexer, retriever, and history buffer. Constructor overrides make it easy to inject fakes in tests—keep those optional parameters intact.【F:src/core/memory/MemoryManager.js†L1-L37】
- Vector indexing embeds user/assistant turns plus tool metadata, while retrieval re-ranks with sparse attention. Updates must remain promise-based so orchestration can await them without blocking the UI thread.【F:src/core/memory/services/VectorIndexer.js†L1-L20】【F:src/core/memory/services/Retriever.js†L1-L27】

## Execution hygiene

- When augmenting tool execution or prompts, add coverage under `__tests__` and run the baseline checks (`npm test`, `npm run lint`, `npm run format:check`).【F:package.json†L6-L14】
- If you introduce new workflow steps or tracing metadata, keep `docs/agent-architecture.md` in sync and capture any novel insights in `reports/` for future debugging sessions.【F:docs/agent-architecture.md†L3-L25】【F:REPORT.md†L1-L13】

## Adaptive feedback loop

- Use `WorkflowTracer` output when diagnosing regressions, then record the root cause and mitigation in the repository-wide living history (root `AGENTS.md`) so future runs can adapt faster.【F:src/core/workflows/WorkflowTracer.js†L37-L116】【F:AGENTS.md†L17-L55】
- When tool parsing bugs surface, add reproduction logs and the fix summary to this guide before merging. This keeps the guardrails evolving alongside the orchestration logic.

### Living history

- Structured tracing around `executeTools` has repeatedly exposed mis-registered tool names—retain the tracer hand-offs when refactoring to avoid losing that signal.【F:src/core/AgentOrchestrator.js†L125-L149】
- Argument validation in `_parseArgs` prevented silent prompt corruption during previous experiments; keep new tool syntaxes compatible with that parser or expand it with targeted tests before rollout.【F:src/core/tools/ToolHandler.js†L31-L109】
