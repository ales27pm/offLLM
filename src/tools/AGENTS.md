# Tool Modules Guide

## Export shape

- Export each tool as an object exposing `name`, `description`, `parameters`, and an async `execute` that returns JSON-serializable data; the runtime auto-registers anything with an `execute` function.【F:src/core/tools/ToolRegistry.js†L5-L31】
- Keep parameter metadata (`type`, `required`, `default`, `enum`, `validate`) up to date so `PromptBuilder` can describe invocation contracts accurately.【F:src/tools/webSearchTool.js†L4-L44】【F:src/core/prompt/PromptBuilder.js†L6-L26】

## Platform awareness

- iOS adapters call into numerous TurboModules (calendar, messages, maps, contacts, sensors, etc.). Guard optional parameters and fall back gracefully to avoid runtime crashes when the user denies permissions.【F:src/tools/iosTools.js†L1-L120】
- Android currently exposes explicit "unsupported" stubs that throw informative errors; keep those in sync with the iOS tool names so the agent can degrade gracefully on the wrong platform.【F:src/tools/androidTools.js†L1-L16】

## Error handling & telemetry

- Return structured `{ success, … }` payloads instead of throwing when possible—`webSearchTool` is the template to follow, surfacing provider/query alongside success state.【F:src/tools/webSearchTool.js†L46-L85】
- Log recoverable failures through the calling service/tool so `WorkflowTracer` captures them; update root living history if a new category of tool error emerges.【F:src/core/tools/ToolHandler.js†L112-L157】【F:AGENTS.md†L31-L55】

## Adaptive feedback loop

- When adding or modifying tools, record new validation rules or platform quirks in this file and the repository-wide history to keep tool affordances current.
- Update `docs/agent-architecture.md` when the available tool roster or categories change so documentation matches runtime reality.【F:docs/agent-architecture.md†L21-L25】

### Living history

- Keeping Android stubs throwing explicit "unsupported" errors prevented silent failures during parity testing—continue matching stub names to their iOS counterparts for clarity.【F:src/tools/androidTools.js†L1-L16】
- Returning `{ success: false }` payloads from `webSearchTool` surfaced API key misconfigurations early; preserve that pattern when integrating additional providers.【F:src/tools/webSearchTool.js†L56-L84】
