# Architecture & Plugins Guide

## Plugin lifecycle

- `PluginManager` owns registration, hook wiring, enable/disable flows, and module patch bookkeeping. Always route overrides through `registerPlugin`/`enablePlugin` so `_replaceModuleFunction` can capture originals and restore them cleanly.【F:src/architecture/pluginManager.js†L10-L204】
- Global patches only fire when the target path contains a dot; keep that guard in place to avoid clobbering instance methods unintentionally.【F:src/architecture/pluginManager.js†L35-L48】
- When adding hooks, go through `registerHook`/`executeHook` instead of iterating arrays manually to maintain deterministic ordering and error isolation.【F:src/architecture/pluginManager.js†L95-L118】

## Dependency injection & setup

- Dependency wiring runs through `DependencyInjector` and `setupLLMDI`; register shared state there instead of importing singletons directly.【F:src/architecture/dependencyInjector.js†L1-L24】【F:src/architecture/diSetup.js†L1-L5】
- Bundle built-in plugins in `registerLLMPlugins` so the runtime enables them immediately after the model loads. Mirror that pattern when shipping new plugins (e.g., hardware-aware ones).【F:src/architecture/pluginSetup.js†L1-L28】【F:src/services/llmService.js†L41-L107】

## Advanced tool system

- `src/architecture/toolSystem.js` provides categorized tool registration, usage analytics, validation, and the MCP client. Keep statistics (`usageCount`, `executionHistory`) in sync when you add new execution paths or retries.【F:src/architecture/toolSystem.js†L1-L200】
- The `MCPClient` queues messages until a WebSocket connection is ready and auto-reconnects with backoff; preserve that flow when extending transport features to avoid dropping tool calls.【F:src/architecture/toolSystem.js†L130-L199】

## Adaptive feedback loop

- When plugin overrides or MCP integrations misbehave, capture the reproduction plus mitigation in `reports/` and echo the distilled lesson in the repository-wide living history so future debugging starts with context.【F:REPORT.md†L1-L13】【F:AGENTS.md†L29-L45】
- Update `docs/agent-architecture.md` after altering plugin activation order, dependency wiring, or tool analytics so documentation reflects the new behavior.【F:docs/agent-architecture.md†L15-L25】

### Living history

- Guarding `_replaceModuleFunction` with a dotted module path prevented accidental overrides of service instances; keep that restriction as you add new patch targets.【F:src/architecture/pluginManager.js†L35-L48】
- Tool usage analytics have surfaced regressions in prompt prompts; continue recording executions in `executionHistory` to fuel that feedback loop.【F:src/architecture/toolSystem.js†L20-L58】
