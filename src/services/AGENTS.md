# Services & Tools Guide

## LLM runtime

- `llmService` handles model download, native bridge selection, plugin enablement, KV-cache maintenance, inference metrics, and adaptive quantization scheduling. Keep the `loadModel → clearKVCache → generate` flow intact so plugins and cache sizing stay coherent across platforms.【F:src/services/llmService.js†L14-L187】
- Generation routes through `PluginManager.execute` when sparse attention is active; ensure new options are plumbed into both native and web code paths so overrides stay consistent.【F:src/services/llmService.js†L116-L175】
- Embedding requires a loaded model on device; guard new entry points with informative errors instead of silent fallbacks.【F:src/services/llmService.js†L200-L238】

## Context planning

- `ContextEngineer` provides hierarchical attention, similarity/quality scoring, and device-aware pruning. Preserve its deterministic behavior—outputs feed directly into prompt assembly and sparse attention heuristics.【F:src/services/contextEngineer.js†L15-L179】
- Keep vector-store contracts intact when swapping implementations; the constructor enforces a `searchVectors` function to avoid runtime surprises.【F:src/services/contextEngineer.js†L182-L200】

## Content & search utilities

- `ReadabilityService` caches `(html, url)` signatures, strips unsafe nodes, and normalizes metadata (title, byline, published time). Maintain cache invalidation and error wrapping so callers receive actionable responses.【F:src/services/readabilityService.js†L3-L159】
- `SearchService` validates API keys, rate limits provider calls, and enriches results via `extractFromUrl`; keep that enrichment path intact to avoid reintroducing the deprecated `extract` call.【F:src/services/webSearchService.js†L11-L64】
- `webSearchTool` exposes a JSON-serializable interface with parameter validation—mirror that contract for new service-backed tools.【F:src/tools/webSearchTool.js†L1-L85】
- Long-form reasoning utilities such as `TreeOfThoughtReasoner` rely on `llmService.generate`; update both sides whenever you adjust return signatures or scoring heuristics.【F:src/services/treeOfThought.js†L1-L191】【F:src/services/llmService.js†L116-L187】

## Adaptive feedback loop

- Capture performance heuristics (KV cache pressure, inference time) in `report_agent.md` or related diagnostics when they inform service-level changes, and echo key takeaways in the living history below.【F:report_agent.md†L1-L9】
- After introducing a new provider or plugin-aware service, refresh `docs/agent-architecture.md` and add regression tests to keep the behavior discoverable.【F:docs/agent-architecture.md†L26-L34】

### Living history

- Switching `performSearchWithContentExtraction` to `extractFromUrl` fixed downstream crashes when the old `extract` API was missing—do not regress that call path.【F:src/services/webSearchService.js†L35-L64】
- Adaptive quantization adjustments rely on averaged inference time and memory metrics; keep those counters accurate or you will lose the self-tuning benefits.【F:src/services/llmService.js†L153-L208】
