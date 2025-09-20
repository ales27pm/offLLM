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

const normalizeContextEntry = (entry) => {
  if (typeof entry === "string") {
    return entry;
  }

  if (entry && typeof entry.content === "string") {
    return entry.content;
  }

  return "";
};

export default class PromptBuilder {
  constructor(toolRegistry) {
    this.toolRegistry = toolRegistry;
  }

  build(userPrompt, context = []) {
    const contextStr = context.map(normalizeContextEntry).join("\n");
    const tools = this.toolRegistry.getAvailableTools();
    const toolsStr = (Array.isArray(tools) ? [...tools] : [])
      .sort((toolA, toolB) => {
        const nameA =
          toolA && typeof toolA.name === "string"
            ? toolA.name.trim().toLowerCase()
            : "";
        const nameB =
          toolB && typeof toolB.name === "string"
            ? toolB.name.trim().toLowerCase()
            : "";

        return nameA.localeCompare(nameB);
      })
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
