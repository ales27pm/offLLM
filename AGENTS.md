# OffLLM Contributor Guide

This repository ships a ReAct-style agent runtime with plugins, tools, and adaptive memory. Start every change by scanning `docs/agent-architecture.md`; any edits to the orchestrator, memory pipeline, plugins, or services must keep that document accurate.

## Workflow Expectations

- Keep commits focused and use [Conventional Commit](https://www.conventionalcommits.org/) messages.
- Leave the working tree clean. Run formatting and tests locally before committing.
- When platform tooling is required (iOS/Android), document the exact steps taken in the PR description.

### Required Checks

Run the JavaScript/TypeScript checks on every change:

```bash
npm test
npm run lint
npm run format:check
```

Run targeted native builds only when touching platform code:

```bash
# iOS
npm ci
(cd ios && xcodegen generate && bundle install && bundle exec pod install --repo-update)
./scripts/ios_doctor.sh
npx react-native run-ios --scheme monGARS

# Android
npm ci
./android/gradlew :app:assembleDebug
```

## Directory Guide

- `docs/`: `agent-architecture.md` is the canonical architecture reference. Update the relevant sections whenever you change orchestration, memory, plugin wiring, or tool exposure. Other documents should cross-link to this guide instead of duplicating logic.
- `src/core/`: Contains the runtime loop (`AgentOrchestrator`), prompt builder, tool parser/executor, and in-process memory components. Keep tool contracts synchronized between `PromptBuilder`, `ToolHandler`, and `toolRegistry`. If you add a new tool signature, update all three.
- `src/architecture/`: Hosts the pluggable LLM runtime (`pluginManager`, `pluginSetup`, dependency injection, and the advanced `toolSystem`). Plugin modules must register through the manager and guard platform capabilities before overriding `LLMService` methods.
- `src/services/`: Shared services exposed as agent tools or background helpers. Key modules include `llmService` (model runtime), `contextEngineer` (context planning), `readabilityService`, `webSearchService`, and `treeOfThought`. Keep APIs promise-based and side-effect free except for clearly documented caching or storage calls.
- `src/tools/`: Lightweight tool wrappers (`webSearchTool`, `iosTools`, `androidTools`). Surface only serializable inputs/outputs so the orchestrator can record tool traces in memory.
- `src/memory/`: Persistence layer (vector storage and migrations). Coordinate schema updates with `src/core/memory` so retrieval stays compatible.
- `reports/`, `ci-reports/`, `REPORT.md`, `report_agent.md`: Generated artifacts. Never edit manually—regenerate via the appropriate npm or CI scripts.
- `ios/` and `android/`: Native shells. Commit source changes only; keep derived data, build outputs, and Pods caches out of version control.
- `tools/` and `scripts/`: Developer utilities (e.g., `ios_doctor.sh`, `xcresult-parser.js`). Keep them idempotent and document new commands inline.

## Codegen & TurboModules

- Specs live in `src/specs/`. After modifying them run `npm run codegen` followed by `bundle exec pod install --repo-update` to refresh native bindings.
- Implement TurboModules Swift-first (TypeScript spec → Swift class → Objective-C++ bridge). JavaScript callers should request them via `TurboModuleRegistry.getOptional('Name')` with graceful fallbacks for legacy modules.

## Logging & Diagnostics

- Enable verbose logging with `DEBUG_LOGGING=1` (via `react-native-config`); logs are written to `logs/app.log`.
- Set `DEBUG_PANEL=1` to open the in-app debug console for inspecting or clearing logs.

Adhering to these guidelines keeps the OffLLM agent stack consistent with the documented architecture while ensuring reproducible builds across JavaScript and native surfaces.
