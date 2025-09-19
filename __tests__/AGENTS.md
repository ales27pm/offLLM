<!-- prettier-ignore-start -->
# Test Suites Guide

## Scope & layout

- Jest coverage for the runtime, services, tools, and storage lives here; when you change their contracts, mirror those updates
  in the matching suite (`llmService`, `toolHandler`, `vectorMemory`, `workflowTracer`, `logger`, etc.).【F:__tests__/llmService.test.js†L1-L48】【F:__tests__/toolHandler.test.js†L1-L91】【F:__tests__/vectorMemory.test.js†L1-L43】【F:__tests__/workflowTracer.test.js†L1-L56】【F:__tests__/logger.test.ts†L1-L49】
- Keep fixtures lightweight—tests rely on inline mocks and deterministic helper data instead of large snapshots. Extend that
  pattern when introducing new coverage so we can run `npm test` quickly in CI.【F:__tests__/llmService.test.js†L6-L29】【F:__tests__/toolHandler.test.js†L5-L90】

## Authoring guidance

- Treat every bugfix as a test-first exercise. Reproduce failing tool parses, orchestrator flows, or memory persistence inside
  these suites before you ship the patch so regressions can be caught automatically.【F:__tests__/toolHandler.test.js†L5-L90】【F:__tests__/vectorMemory.test.js†L8-L43】
- Prefer exercising public APIs (e.g., `ToolHandler.parse`, `VectorMemory.recall`, `WorkflowTracer.withStep`) and let the
  assertions document required side effects like telemetry output or encryption. This keeps tests resilient to refactors while
  protecting observable behaviour.【F:__tests__/toolHandler.test.js†L36-L90】【F:__tests__/vectorMemory.test.js†L8-L43】【F:__tests__/workflowTracer.test.js†L24-L55】
- When you add new modules, colocate their suites here and wire them into Jest by exporting from the existing barrel or by
  relying on automatic discovery—no custom config is required for files ending with `.test.(js|ts)`. The default script `npm test`
  already watches this glob.【F:package.json†L6-L15】

## Execution & maintenance

- Run `npm test` locally (and optionally `npm run test:ci` for coverage) before committing. The root quality gates (`npm run lint`,
  `npm run format:check`) must still pass so tests stay readable and lintable.【F:package.json†L6-L15】
- When tests depend on generated diagnostics (e.g., verifying logs or report artefacts), prefer stubbing filesystem reads over
  checking real files to avoid brittle assertions; see the logger suite’s mock-based strategy for an example.【F:__tests__/logger.test.ts†L5-L48】

## Adaptive feedback loop

- After each CI failure, capture the reproduction steps in a new or updated test and cross-link the relevant diagnostic snippet
  (from `CI-REPORT.md` or `report_agent.md`) inside the test description or comments. That keeps the suite aligned with the most
  recent incidents.【F:CI-REPORT.md†L1-L13】【F:report_agent.md†L1-L10】
- Append a short note to the living history below whenever a new test neutralises a regression, citing the failing report so the
  next contributor understands the context. If diagnostics changed, sync them via `npm run reports:commit` after tests pass.【F:package.json†L25-L29】

### Living history

- Parser coverage in `toolHandler.test.js` caught malformed-argument regressions during previous prompt experiments—retain and
  expand those cases when you evolve the parsing grammar.【F:__tests__/toolHandler.test.js†L5-L90】
- The persistent-memory suite verified that encryption stayed intact after schema migrations, preventing silent plaintext dumps
  when storage limits tightened.【F:__tests__/vectorMemory.test.js†L8-L43】
- Workflow tracing tests confirmed that success and error paths both emit structured logs, which helped debug missing telemetry
  during orchestration refactors.【F:__tests__/workflowTracer.test.js†L24-L55】
<!-- prettier-ignore-end -->
