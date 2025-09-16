# Tool Modules Guide

Files in `src/tools` expose lightweight adapters that the agent runtime auto-registers. They should be serializable, platform-aware, and free of side effects beyond calling services.

- Export each tool as a named object with `name`, `description`, `parameters`, and async `execute` returning JSON-serializable data. If the tool is the default export, ensure `ToolRegistry.autoRegister` can still detect the shape.【F:src/core/tools/ToolRegistry.js†L1-L31】
- Validate inputs up front; parameter objects should declare `type`, `required`, defaults, and `validate`/`enum` rules so prompts can describe them accurately.【F:src/tools/webSearchTool.js†L1-L35】
- Catch service errors and return structured `{ success, … }` payloads rather than throwing—this keeps tool traces stable and easy to log.【F:src/tools/webSearchTool.js†L36-L63】
- Platform-specific bundles like `iosTools`/`androidTools` must guard unavailable APIs and fall back gracefully so auto-registration on the wrong platform is a no-op.【F:src/core/tools/ToolRegistry.js†L1-L39】

Always add Jest coverage when introducing a tool; mock downstream services to verify parameter validation and error handling.
