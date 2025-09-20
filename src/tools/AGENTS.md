# Tool Modules Guide

## Export shape
- Export each tool as an object with `name`, `description`, `parameters`, and an async `execute` returning JSON-serialisable data; the runtime auto-registers anything exposing an `execute` function via `toolRegistry.autoRegister`.【F:src/core/tools/ToolRegistry.js†L5-L39】
- Keep parameter metadata (`type`, `required`, `default`, `enum`, `validate`) accurate so `PromptBuilder` can describe invocation contracts precisely.【F:src/tools/webSearchTool.js†L4-L44】【F:src/core/prompt/PromptBuilder.js†L1-L27】

## Platform awareness
- iOS adapters call into numerous TurboModules (calendar, messages, maps, contacts, sensors, etc.). Guard optional parameters and fail gracefully to avoid crashes when permissions are denied or modules are missing.【F:src/tools/iosTools.js†L1-L200】
- Android currently exposes explicit "unsupported" stubs that throw informative errors; keep stub names aligned with the iOS counterparts so the agent can degrade gracefully on the wrong platform.【F:src/tools/androidTools.js†L1-L15】

## Error handling & telemetry
- Return structured `{ success, … }` payloads instead of throwing when possible—`webSearchTool` is the template, surfacing provider/query alongside success state so upstream logging stays actionable.【F:src/tools/webSearchTool.js†L46-L85】
- Log recoverable failures through the calling service/tool so `WorkflowTracer` captures them; update the living history when a new category of tool error emerges.【F:src/core/tools/ToolHandler.js†L112-L157】【F:src/core/workflows/WorkflowTracer.js†L24-L115】

## Dynamic feedback loop
- When adding or modifying tools, record new validation rules or platform quirks in this guide and the repository-wide history to keep tool affordances current.【F:AGENTS.md†L1-L74】
- Update `docs/agent-architecture.md` and relevant tests when the available tool roster or categories change so documentation matches runtime reality.【F:docs/agent-architecture.md†L21-L78】【F:__tests__/AGENTS.md†L1-L37】

### Living history
- 2025-02 – Keeping Android stubs throwing explicit "unsupported" errors prevented silent failures during parity testing—continue matching stub names to their iOS counterparts for clarity.【F:src/tools/androidTools.js†L1-L15】
- 2025-02 – Returning `{ success: false }` payloads from `webSearchTool` surfaced API key misconfigurations early; preserve that pattern when integrating additional providers.【F:src/tools/webSearchTool.js†L56-L85】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
