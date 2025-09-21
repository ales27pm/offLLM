# Persistent Memory Guide

## Responsibilities
- `VectorMemory` encrypts every payload with AES-256-GCM, enforces storage quotas via `_enforceLimits`, and runs schema migrations on load. Keep those guarantees intact before persisting new data formats.【F:src/memory/VectorMemory.ts†L45-L136】【F:src/memory/migrations/index.ts†L1-L8】
- Memory APIs (`remember`, `recall`, `wipe`, `export`, `import`) operate on plain JavaScript objects so the agent loop and diagnostics can serialise state without special handling—maintain that contract when evolving the schema.【F:src/memory/VectorMemory.ts†L63-L135】
- Migrations are forward-only; bump `CURRENT_VERSION` and add a new file under `migrations/` when evolving the schema, ensuring existing data upgrades automatically.【F:src/memory/migrations/index.ts†L1-L8】

## Integration points
- The in-process `MemoryManager` depends on this layer for persistent recall—coordinate API changes with the in-memory services to avoid drift between runtime retrieval and disk storage.【F:src/core/memory/MemoryManager.js†L8-L34】
- Encryption keys default to an ephemeral value in development. Configure `MEMORY_ENCRYPTION_KEY` (32 chars) in production so stored vectors remain decryptable across restarts.【F:src/memory/VectorMemory.ts†L23-L37】

## Dynamic feedback loop
- Log migration outcomes or storage pressure in your PR or team notes whenever limits are hit, and capture the root cause plus mitigation in the living history so storage heuristics can be tuned iteratively; the legacy report pipeline is retired.【F:Steps.md†L1-L108】
- Update documentation and tests when retrieval strategies, quota enforcement, or encryption policies change so consumers know how to adapt.【F:docs/agent-architecture.md†L9-L58】【F:__tests__/vectorMemory.test.js†L8-L43】

### Living history
- 2025-02 – Development builds previously lost persisted data when the encryption key rotated; setting `MEMORY_ENCRYPTION_KEY` resolved the issue—do not rely on the ephemeral fallback outside local testing.【F:src/memory/VectorMemory.ts†L23-L37】
- 2025-02 – Tightening `_enforceLimits` to trim the oldest entries kept encrypted blobs under quota without data corruption; retain that LRU-style loop when adjusting limits.【F:src/memory/VectorMemory.ts†L120-L135】

### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
