# Core Runtime Guide

The `src/core` tree houses the orchestrator loop, prompt scaffolding, plugin glue, and the in-process memory helpers that sit between services and the UI. Any change here must preserve the control flow documented in `docs/agent-architecture.md`.

## Orchestrator & prompt rules

- Keep `AgentOrchestrator.run` in a single async pass that (1) retrieves vector and history context, (2) builds a prompt, (3) executes tool calls returned by the first model pass, and (4) persists the final exchange back to memory before returning.【F:src/core/AgentOrchestrator.js†L1-L42】
- `PromptBuilder` should describe every registered tool with name, description, and JSON-serializable parameter schema; avoid inlining business logic inside templates.【F:src/core/prompt/PromptBuilder.js†L1-L26】
- When expanding the prompt format, keep it deterministic and ensure the same context array yields the same string (ordering and separators matter for caching).

## Tool handling

- Treat `ToolRegistry` as the source of truth for callable tools; every entry must expose `{ name, description, parameters, execute }` and be auto-registered for the active platform.【F:src/core/tools/ToolRegistry.js†L1-L39】
- `ToolHandler` must continue to parse `TOOL_CALL:` directives, validate arguments, and surface structured `{ role: "tool", name, content }` records. Extend `_parseArgs` rather than bypassing its validation logic.【F:src/core/tools/ToolHandler.js†L1-L53】
- When adding new tool output types, ensure they serialize to JSON strings so memory and prompt builders can ingest them without mutation.

## Memory helpers

- `MemoryManager` stitches together vector indexing, retrieval, and rolling history; keep constructor parameters optional and promise-based so tests can inject fakes.【F:src/core/memory/MemoryManager.js†L1-L34】
- `VectorIndexer`, `Retriever`, and `HistoryService` should remain side-effect free beyond their documented responsibilities (indexing, sparse-attention ranking, bounded history). Do not introduce global singletons here.【F:src/core/memory/services/VectorIndexer.js†L1-L24】【F:src/core/memory/services/Retriever.js†L1-L33】【F:src/core/memory/services/HistoryService.js†L1-L15】

## Testing

- Add or update unit tests under `__tests__/` whenever you change parsing, orchestration flow, or memory semantics, and run `npm test` before committing.
