# Persistent Memory Guide

## Responsibilities

- `VectorMemory` encrypts every payload with AES-256-GCM, enforces storage quotas via `_enforceLimits`, and runs schema migrations on load. Keep those guarantees intact before persisting new data formats.【F:src/memory/VectorMemory.ts†L1-L108】【F:src/memory/VectorMemory.ts†L120-L161】【F:src/memory/migrations/index.ts†L1-L9】
- `remember`, `recall`, `wipe`, `export`, and `import` should continue to operate on plain JavaScript objects so the agent loop and diagnostics can serialize state without special handling.【F:src/memory/VectorMemory.ts†L63-L118】【F:src/memory/VectorMemory.ts†L130-L168】
- Migrations are forward-only; bump `CURRENT_VERSION` and add a dedicated file under `migrations/` when evolving the schema.【F:src/memory/migrations/index.ts†L1-L9】

## Integration points

- The in-process `MemoryManager` depends on this layer for persistent recall—coordinate API changes with the in-memory services to avoid drift between runtime retrieval and disk storage.【F:src/core/memory/MemoryManager.js†L1-L34】
- Encryption keys default to an ephemeral value in development. Configure `MEMORY_ENCRYPTION_KEY` (32 chars) in production so stored vectors remain decryptable across restarts.【F:src/memory/VectorMemory.ts†L18-L47】

## Adaptive feedback loop

- Log migration outcomes or storage pressure in `reports/` whenever limits are hit; surface the root cause in the living history so storage heuristics can be tuned iteratively.【F:REPORT.md†L1-L13】
- Update `docs/agent-architecture.md` if retrieval strategies or storage guarantees change to keep external docs accurate.【F:docs/agent-architecture.md†L9-L13】

### Living history

- Development builds previously lost persisted data when the encryption key rotated; setting `MEMORY_ENCRYPTION_KEY` resolved the issue—do not rely on the ephemeral fallback outside local testing.【F:src/memory/VectorMemory.ts†L18-L37】
- Tightening `_enforceLimits` to trim the oldest entries first kept encrypted blobs under quota without data corruption; retain that LRU-style loop when adjusting limits.【F:src/memory/VectorMemory.ts†L120-L152】
