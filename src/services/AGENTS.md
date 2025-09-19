# Services & Tools Guide

## LLM runtime
- `llmService` handles model download, native bridge selection, plugin enablement, KV-cache maintenance, embeddings, and adaptive quantisation scheduling. Keep the `loadModel → clearKVCache → generate` flow intact so plugins and cache sizing stay coherent across platforms.【F:src/services/llmService.js†L14-L350】
- Generation routes through `PluginManager.execute` when sparse attention is active; ensure new options are plumbed into both native and web code paths so overrides remain consistent.【F:src/services/llmService.js†L116-L187】
- Embedding requires a loaded model on device—guard new entry points with informative errors instead of silent fallbacks.【F:src/services/llmService.js†L236-L250】

## Context planning
- `ContextEngineer` provides hierarchical attention, similarity/quality scoring, sparse retrieval fallbacks, and device-aware token budgeting; changes must respect its vector-store contract and deterministic behaviour because orchestration depends on the returned prompt budget.【F:src/services/contextEngineer.js†L182-L444】
- The accompanying `ContextEvaluator` clusters context, adjusts quality scores based on metadata, and can fall back gracefully when hierarchical attention fails—keep those heuristics in sync with device detection logic.【F:src/services/contextEngineer.js†L15-L180】

## Content & search utilities
- `ReadabilityService` caches `(html, url)` pairs, strips unsafe nodes, normalises metadata (title, byline, published time), and exposes helpers for published date parsing; maintain cache invalidation and error messages so callers receive actionable responses.【F:src/services/readabilityService.js†L3-L159】
- `SearchService` wraps multiple providers, validates API keys, rate-limits calls, and enriches results via `extractFromUrl`; the exported `webSearchTool` mirrors those semantics and returns structured success/error payloads. Keep provider names and parameter metadata aligned across both layers.【F:src/services/webSearchService.js†L1-L65】【F:src/tools/webSearchTool.js†L4-L85】

## Reasoning utilities
- `TreeOfThoughtReasoner` implements multi-branch reasoning with candidate generation, scoring, and path selection, delegating all generation/evaluation to `llmService.generate`. Update both sides when you change return signatures or heuristics.【F:src/services/treeOfThought.js†L1-L191】【F:src/services/llmService.js†L116-L208】

## Dynamic feedback loop
- Capture performance heuristics (KV cache pressure, inference time, quantisation switches) in the generated reports when they inform service-level changes, and mirror key takeaways in the living history below.【F:report_agent.md†L1-L10】
- After introducing a new provider, plugin-aware service, or reasoning primitive, refresh `docs/agent-architecture.md` and extend the relevant tests so the behaviour stays discoverable.【F:docs/agent-architecture.md†L26-L78】【F:__tests__/AGENTS.md†L1-L37】

### Living history
- 2025-02 – Switching `performSearchWithContentExtraction` to `extractFromUrl` fixed downstream crashes when the deprecated `extract` API was missing—do not regress that call path.【F:src/services/webSearchService.js†L21-L64】
- 2025-02 – Adaptive quantisation relies on averaged inference time and memory metrics; keep those counters accurate or you lose the self-tuning benefits.【F:src/services/llmService.js†L153-L350】
