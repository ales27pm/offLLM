# Persistent Memory Guide

The `src/memory` directory implements encrypted, on-disk vector memory and migrations for long-term recall outside the in-process `MemoryManager`. Treat it as a persistence layer with strict size and security guarantees.

- `VectorMemory` must keep data encrypted at rest via `EncryptionService` and enforce storage limits through `_enforceLimits`; never write plaintext vectors to disk.【F:src/memory/VectorMemory.ts†L1-L108】【F:src/memory/VectorMemory.ts†L141-L168】
- Always run `runMigrations` after loading stored data so new schemas can evolve without wiping history.【F:src/memory/VectorMemory.ts†L1-L64】
- Expose APIs that return plain JavaScript/TypeScript objects—avoid leaking buffers so the agent loop can serialize state safely.
- When adding migrations, include forward-only transforms under `src/memory/migrations` and update `CURRENT_VERSION` accordingly.

Tests touching this layer should mock filesystem paths and provide deterministic keys; run `npm test` before committing changes here.
