# Services & Tools Guide

Modules under `src/services` wrap platform capabilities or long-running logic so the orchestrator can call them as tools. Keep each service promise-based, side-effect aware, and friendly to plugin instrumentation.

## LLM service

- `llmService` owns model lifecycle, plugin registration, and KV-cache bookkeeping. Preserve the lazy `loadConfiguredModel → loadModel → generate` flow and leave plugin toggles inside `loadModel` so sparse attention and adaptive quantization stay in sync.【F:src/services/llmService.js†L1-L117】
- `generate` must route through the plugin manager when `sparseAttention` is enabled and always normalize responses to `{ text, … }` objects before tracking inference metrics and cache usage.【F:src/services/llmService.js†L118-L205】
- When adjusting performance heuristics, update `adjustQuantization`, `adjustPerformanceMode`, and KV-cache helpers together so metrics remain coherent.【F:src/services/llmService.js†L205-L324】

## Context planning & retrieval

- `contextEngineer` should remain deterministic: keep token budgeting, hierarchical attention, and quality scoring pure functions that log errors but fall back gracefully.【F:src/services/contextEngineer.js†L1-L116】
- Avoid synchronous tokenization on the hot path; reuse the cached tokenizer and guard against failures when `encoding_for_model` is unavailable.【F:src/services/contextEngineer.js†L9-L36】

## Content & search utilities

- `readabilityService` must cache by `(html, url)` signature, strip unsafe nodes, and return `{ text, metadata }` payloads ready for prompts. Preserve error wrapping so the orchestrator receives actionable failures.【F:src/services/readabilityService.js†L1-L78】
- `webSearchService` and any derived tools should validate API keys before network calls and respect the `performSearchWithContentExtraction` contract (returns provider-tagged result arrays).【F:src/tools/webSearchTool.js†L1-L63】
- Keep `treeOfThought` exports pure and deterministic—no hidden globals or timers—so they can run inside the agent loop repeatedly without leaks.【F:src/services/treeOfThought.js†L1-L191】

## Testing

- Mock network and native modules in unit tests; services that touch the filesystem or network must ship Jest mocks under `__mocks__/` or inline fakes. Always run `npm test` and `npm run lint` when modifying this directory.
