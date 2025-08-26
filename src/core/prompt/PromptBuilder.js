export default class PromptBuilder {
  constructor(toolRegistry) {
    this.toolRegistry = toolRegistry;
  }

  build(userPrompt, context = []) {
    const contextStr = context.map((c) => c.content).join("\n");
    const toolsStr = this.toolRegistry
      .getAvailableTools()
      .map(
        (t) =>
          `Tool: ${t.name} - ${t.description} (Params: ${JSON.stringify(
            t.parameters,
          )})`,
      )
      .join("\n");

    return `
You are an AI assistant with access to:
${toolsStr}

Context:
${contextStr}

User: ${userPrompt}
Assistant:`;
  }
}
