<!-- prettier-ignore-start -->
# Test Suites Guide

## Scope & layout
- Jest coverage here protects the runtime, services, tools, and storage layers—keep the suites in sync with the contracts they exercise (`llmService`, `toolHandler`, `vectorMemory`, `workflowTracer`, `logger`, etc.).【F:__tests__/llmService.test.js†L6-L48】【F:__tests__/toolHandler.test.js†L5-L90】【F:__tests__/vectorMemory.test.js†L8-L43】【F:__tests__/workflowTracer.test.js†L24-L56】【F:__tests__/logger.test.ts†L19-L48】
- Stick to lightweight fixtures: each suite relies on inline mocks or deterministic helper data instead of large snapshots so `npm test` remains fast and deterministic in CI.【F:__tests__/toolHandler.test.js†L5-L90】【F:__tests__/vectorMemory.test.js†L8-L43】

## Authoring guidance
- Treat every bug fix as a test-first change. Reproduce malformed tool calls, orchestration regressions, or persistence issues inside these suites before landing the patch so CI can guard against regressions automatically.【F:__tests__/toolHandler.test.js†L27-L75】【F:__tests__/vectorMemory.test.js†L27-L43】
- Prefer exercising public entry points (`ToolHandler.parse`, `VectorMemory.recall`, `WorkflowTracer.withStep`, `LLMService.generate`) and let the assertions document expected side effects like logging or encryption. That keeps tests resilient to refactors while preserving observable behaviour.【F:__tests__/toolHandler.test.js†L36-L90】【F:__tests__/vectorMemory.test.js†L8-L43】【F:__tests__/workflowTracer.test.js†L24-L56】【F:__tests__/llmService.test.js†L37-L48】
- New modules belong here: co-locate their suites under `__tests__/` and rely on Jest’s default glob (`*.test.(js|ts)`)—no extra config is needed beyond exporting the file.【F:package.json†L6-L15】

## Execution & maintenance
- Run `npm test` locally (and `npm run test:ci` for coverage) before committing; the root quality gates (`npm run lint`, `npm run format:check`) must also pass so the suites stay readable and lintable.【F:package.json†L10-L14】
- When tests depend on diagnostics, prefer stubbing filesystem reads or logger output instead of asserting on real report files; the logger suite shows how to mock persistent storage safely.【F:__tests__/logger.test.ts†L30-L48】

## Dynamic feedback loop
- When CI fails, capture the reproduction in a focused test, cite the triggering log or PR comment in the test description or comments, and record the summary in the living history below so future contributors can trace the evidence quickly.【F:Steps.md†L1-L108】
- After updating or adding tests that neutralise a failure mode, link to the relevant logs or PR discussion instead of regenerating doctor reports; the automated reporting pipeline has been retired.【F:scripts/dev/doctor.sh†L277-L339】

### Living history
- 2025-02 – Parser coverage in `toolHandler.test.js` caught malformed argument strings and ensured `_parseArgs` rejects invalid payloads—extend those cases when evolving the prompt grammar.【F:__tests__/toolHandler.test.js†L27-L90】
- 2025-02 – The persistent memory suite verified encryption-at-rest and migration bumps, preventing plaintext leaks when storage limits tightened.【F:__tests__/vectorMemory.test.js†L19-L43】
- 2025-02 – Workflow tracer tests confirmed that success and error paths emit structured logs, making orchestration regressions easier to diagnose with saved traces.【F:__tests__/workflowTracer.test.js†L24-L56】
 
### Session reflection
- Before ending the session, save the current run's successes and errors so the next session can build on what worked and avoid repeating mistakes.
<!-- prettier-ignore-end -->
