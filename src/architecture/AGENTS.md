# Architecture & Plugins Guide

## Plugin lifecycle
- `PluginManager` owns registration, hook execution, and module patch bookkeeping. Route overrides through `registerPlugin`/`enablePlugin` so `_replaceModuleFunction` can capture originals and restore them cleanly; global patches only fire when the target path includes a dot to avoid clobbering instances.【F:src/architecture/pluginManager.js†L10-L204】
- Register hook handlers with `registerHook`/`executeHook` instead of iterating arrays manually so execution order and error isolation remain deterministic.【F:src/architecture/pluginManager.js†L95-L118】
- `execute` checks for overrides before delegating to the base context method, and records module patches so `disablePlugin` can restore the original behaviour—preserve this guardrail when adding new plugin capabilities.【F:src/architecture/pluginManager.js†L118-L204】

## Dependency injection & setup
- Dependency wiring flows through `DependencyInjector` and `setupLLMDI`; register shared state there instead of importing singletons so plugins can access the same instances.【F:src/architecture/dependencyInjector.js†L1-L24】【F:src/architecture/diSetup.js†L1-L5】
- Bundle built-in plugins via `registerLLMPlugins` so the runtime enables them immediately after the model loads; mirror that pattern when shipping new plugins (e.g., hardware-aware ones).【F:src/architecture/pluginSetup.js†L1-L28】【F:src/services/llmService.js†L14-L187】

## Advanced tool system
- `src/architecture/toolSystem.js` exposes a richer `ToolRegistry` with categories, validation, usage analytics, and a `MCPClient` capable of queueing requests until a WebSocket connection is live. Keep statistics (`usageCount`, `executionHistory`) and parameter validation in sync when you add new execution paths or retries.【F:src/architecture/toolSystem.js†L1-L200】
- The `MCPClient` auto-reconnects with backoff, tracks pending requests, and flushes queued messages once the socket opens; maintain those safeguards when extending transport features to avoid dropping tool calls.【F:src/architecture/toolSystem.js†L200-L392】

## Dynamic feedback loop
- When plugin overrides or MCP integrations misbehave, capture the reproduction plus mitigation in the generated reports and echo the distilled lesson in this guide so future debugging starts with context.【F:REPORT.md†L1-L13】【F:report_agent.md†L6-L10】
- Update `docs/agent-architecture.md` and relevant tests after altering plugin activation order, dependency wiring, or tool analytics so external documentation reflects the new behaviour.【F:docs/agent-architecture.md†L21-L78】【F:__tests__/AGENTS.md†L1-L37】

### Living history
- 2025-02 – Guarding `_replaceModuleFunction` with dotted module paths prevented accidental overrides of service instances; keep that restriction as you add new patch targets.【F:src/architecture/pluginManager.js†L35-L104】
- 2025-02 – Tool usage analytics surfaced prompt regressions—continue recording executions in `executionHistory` so adaptive tooling has reliable telemetry.【F:src/architecture/toolSystem.js†L8-L83】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
