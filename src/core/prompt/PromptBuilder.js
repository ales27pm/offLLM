const isNonEmptyString = (value) =>
  typeof value === "string" && value.trim().length > 0;

const normalizeParameters = (parameters) => {
  if (
    parameters &&
    typeof parameters === "object" &&
    !Array.isArray(parameters)
  ) {
    return parameters;
  }
  return {};
};

const normalizeContextEntry = (entry) =>
  entry && typeof entry.content === "string" ? entry.content : "";

export default class PromptBuilder {
  constructor(toolRegistry) {
    this.toolRegistry = toolRegistry;
  }

  build(userPrompt, context = []) {
    const contextStr = context.map(normalizeContextEntry).join("\n");
    const toolsStr = this.toolRegistry
      .getAvailableTools()
      .filter(
        (tool) =>
          tool &&
          isNonEmptyString(tool.name) &&
          isNonEmptyString(tool.description),
      )
      .map((tool) => {
        const parameters = normalizeParameters(tool.parameters);
        return `Tool: ${tool.name.trim()} - ${tool.description.trim()} (Params: ${JSON.stringify(
          parameters,
        )})`;
      })
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
