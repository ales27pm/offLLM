# OffLLM Agent Architecture Guide

## Orchestrator and Control Flow

- `AgentOrchestrator` wires together the language model service, memory, prompt builder, tool handler, and plugin system. The `run` method retrieves long- and short-term context, builds an initial prompt, calls the LLM, parses any `TOOL_CALL` directives, executes the referenced tools, and then issues a final LLM call that incorporates tool output before persisting the exchange to memory.【F:src/core/AgentOrchestrator.js†L1-L46】
- `PromptBuilder` makes the available tool roster explicit by enumerating the registered tools (name, description, parameter schema) and stitching both retrieved context and user input into the prompt template that is handed to the model.【F:src/core/prompt/PromptBuilder.js†L1-L27】
- `ToolHandler` implements the dynamic routing layer: it parses structured tool invocations emitted by the LLM, validates arguments, executes the matching tool instance from the registry, and returns structured results that are appended to the conversational context.【F:src/core/tools/ToolHandler.js†L1-L61】

## Memory and Context Management

- `MemoryManager` couples a vector indexer, retriever, and bounded conversation history so that every interaction is embedded, added to the vector store, and made available for future context retrieval during orchestration.【F:src/core/memory/MemoryManager.js†L1-L37】
- `VectorIndexer`, `Retriever`, and `HistoryService` handle the respective responsibilities of embedding new content, fetching similarity matches (with sparse-attention re-ranking), and tracking the sliding conversational window.【F:src/core/memory/services/VectorIndexer.js†L1-L26】【F:src/core/memory/services/Retriever.js†L1-L37】【F:src/core/memory/services/HistoryService.js†L1-L17】
- `ContextEngineer` provides higher-level context planning features such as hierarchical attention, sparse retrieval fallbacks, device-aware token budgeting, and adaptive summarization so the agent can scale prompts across device tiers.【F:src/services/contextEngineer.js†L1-L409】

## LLM Runtime and Plugin System

- `LLMService` encapsulates model loading, web/native bridging, KV-cache management, embeddings, and quantization heuristics while exposing a single `generate` surface to the orchestrator. It instantiates a `PluginManager`, registers built-in plugins, enables them after the model loads, and routes generation calls through the plugin overrides when active.【F:src/services/llmService.js†L1-L353】
- `PluginManager` supports registering plugins with hook, replace, and extend capabilities, orchestrates lifecycle events, applies module/function overrides, and ensures hooks run before/after delegated calls.【F:src/architecture/pluginManager.js†L1-L228】
- `registerLLMPlugins` currently wires the `sparseAttention` and `adaptiveQuantization` plugins, showing how new plugins can override service methods or add initialization logic. The dependency injector seeds device metrics and cache state for plugin access.【F:src/architecture/pluginSetup.js†L1-L31】【F:src/architecture/dependencyInjector.js†L1-L27】【F:src/architecture/diSetup.js†L1-L5】

## Tool Ecosystem

- The runtime `toolRegistry` auto-registers every native tool exported for the current platform (iOS or Android) so the agent can execute native capabilities like calendar events, location, messaging, and more without manual wiring.【F:src/core/tools/ToolRegistry.js†L1-L39】
- For more advanced scenarios, `src/architecture/toolSystem.js` exposes a richer `ToolRegistry` with categories, validation, usage analytics, and a `MCPClient` that can call remote Model Context Protocol servers, plus sample calculator, web search, and filesystem tools to use as templates.【F:src/architecture/toolSystem.js†L1-L392】

## Services Exposed as Tools or Skills

- `ReadabilityService` fetches, cleans, and caches article content so agent prompts can include readable text along with metadata like title, byline, and reading time.【F:src/services/readabilityService.js†L1-L159】
- `SearchService` wraps multiple web search providers, adds caching and rate-limiting, and optionally enriches results with cleaned page content via the readability service.【F:src/services/webSearchService.js†L1-L68】
- `TreeOfThoughtReasoner` implements multi-branch reasoning with iterative candidate generation, evaluation, and path selection to supply deliberate answers for complex tasks.【F:src/services/treeOfThought.js†L1-L191】

## Extending the Agent

1. **Add a new tool**: export a module with an `execute` function and register it through `toolRegistry.register`, or plug it into the advanced tool system if you need categorization or remote invocation.【F:src/core/tools/ToolRegistry.js†L5-L31】【F:src/architecture/toolSystem.js†L1-L231】
2. **Introduce a plugin**: implement initialization/cleanup and optional `replace`, `extend`, or `hooks` entries, register it with the shared `PluginManager`, and enable it after model load similar to the built-in sparse attention plugin.【F:src/architecture/pluginManager.js†L10-L227】【F:src/architecture/pluginSetup.js†L1-L31】
3. **Augment memory or context**: compose alternative indexers, retrievers, or context engineers by passing custom implementations into `MemoryManager` or extending `ContextEngineer` to tune retrieval and summarization strategies.【F:src/core/memory/MemoryManager.js†L8-L37】【F:src/services/contextEngineer.js†L171-L409】
4. **Expose new services**: follow the patterns in `ReadabilityService`, `SearchService`, or `TreeOfThoughtReasoner` to encapsulate side-effectful capabilities, then surface them to the agent loop as callable tools or background utilities.【F:src/services/readabilityService.js†L1-L159】【F:src/services/webSearchService.js†L11-L68】【F:src/services/treeOfThought.js†L3-L191】

With these components, OffLLM agents can plan, recall context, adjust their runtime characteristics, and call out to a growing catalog of tools while keeping the orchestration loop compact and extensible.
