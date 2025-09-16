# Documentation Guide

This directory stores architecture references and deep-dives that explain how the OffLLM runtime works. Keep every doc synchronized with the current implementation in `src/` and prefer updating `agent-architecture.md` instead of scattering runtime descriptions across multiple files.

## Style

- Use sentence-case headings and wrap lines at 100 characters when possible.
- Maintain the inline citation format (`【F:path†Lx-Ly】`) that links prose back to concrete source files.
- Open each document with a one-paragraph overview that states what changed in the runtime or why the document matters.

## Content expectations

- When the orchestrator loop, memory stack, plugin manager, or tool registry change, reflect the update in `agent-architecture.md` and cite the relevant modules (`AgentOrchestrator`, `PromptBuilder`, `ToolHandler`, `MemoryManager`, `PluginManager`, `registerLLMPlugins`, and `toolRegistry`).
- Document new services or tools by explaining how agents call them and how they integrate with the control loop.
- Prefer diagrams or tables only when they clarify control-flow or data lifecycles; keep them in Markdown for easy review.
