# Architecture & Plugins Guide

This folder contains the dynamic runtime scaffolding that lets the agent adapt model behavior at runtime—plugin management, dependency injection, and the advanced tool registry. Keep changes composable and guard every platform-specific capability.

## Plugin manager

- `PluginManager` is the canonical way to register, enable, and disable plugins. Preserve its lifecycle: `registerPlugin` stores metadata and hooks, `enablePlugin` runs `initialize`, applies `replace`/`extend` patches, and toggles `enabled`, while `disablePlugin` unwinds those patches.【F:src/architecture/pluginManager.js†L1-L104】【F:src/architecture/pluginManager.js†L134-L201】
- Only patch global modules through `_replaceModuleFunction` when the target string contains a dot (`Module.function`); this prevents accidental overrides of service instance methods.【F:src/architecture/pluginManager.js†L31-L86】
- Any new hook must be invoked through `executeHook` so plugin ordering remains deterministic; do not call hook arrays directly.【F:src/architecture/pluginManager.js†L87-L133】

## Dependency injection & setup

- Use `DependencyInjector` for shared runtime state. Register values during initialization (`setupLLMDI`) and resolve them inside services or plugins via `inject`. Throw descriptive errors when dependencies are missing.【F:src/architecture/dependencyInjector.js†L1-L24】【F:src/architecture/diSetup.js†L1-L5】
- `registerLLMPlugins` is the single entry point for bundling built-in plugins. When adding a plugin, register it here and ensure it respects the context object (web vs. native) handed in by `LLMService`.【F:src/architecture/pluginSetup.js†L1-L28】

## Tool system

- The advanced `ToolRegistry` in this folder tracks categories, usage analytics, and MCP connectivity. When registering tools ensure you populate `category`, `parameters`, and any validation functions so `executeTool` can guard inputs.【F:src/architecture/toolSystem.js†L1-L74】
- Use `executeTool` to wrap tool calls; it validates parameters, records execution history, and updates usage metrics. Returning raw results bypasses analytics and is discouraged.【F:src/architecture/toolSystem.js†L20-L63】
- Keep MCP client changes resilient to reconnects and JSON parsing errors; always queue outbound messages until `connect` resolves to avoid dropping calls.【F:src/architecture/toolSystem.js†L75-L170】

## Testing

- When altering plugin wiring or the tool system, add integration coverage (or mocks) under `__tests__/` and run `npm test` plus `npm run lint` to confirm contracts stay intact.
