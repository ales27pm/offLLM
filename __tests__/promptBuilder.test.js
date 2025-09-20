import PromptBuilder from "../src/core/prompt/PromptBuilder";
import ToolHandler from "../src/core/tools/ToolHandler";

class InMemoryToolRegistry {
  constructor(tools = []) {
    this.tools = new Map();
    tools.forEach((tool) => {
      this.register(tool);
    });
  }

  register(tool) {
    this.tools.set(tool.name, tool);
  }

  getAvailableTools() {
    return Array.from(this.tools.values());
  }

  getTool(name) {
    return this.tools.get(name);
  }
}

const createTool = ({ name, description, parameters, execute }) => ({
  name,
  description,
  parameters,
  execute,
});

const buildExpectedPrompt = ({ tools = [], context = [], userPrompt }) => {
  const contextStr = context.map((entry) => entry.content).join("\n");
  const toolsStr = tools
    .map(
      (tool) =>
        `Tool: ${tool.name} - ${tool.description} (Params: ${JSON.stringify(
          tool.parameters,
        )})`,
    )
    .join("\n");

  return [
    "",
    "You are an AI assistant with access to:",
    toolsStr,
    "",
    "Context:",
    contextStr,
    "",
    `User: ${userPrompt}`,
    "Assistant:",
  ].join("\n");
};

describe("PromptBuilder", () => {
  it("weaves tool metadata and retrieved context deterministically", () => {
    const searchTool = createTool({
      name: "search",
      description: "web search",
      parameters: {
        query: { type: "string", required: true },
      },
      execute: async ({ query }) => ({ results: [`result for ${query}`] }),
    });

    const codeTool = createTool({
      name: "code",
      description: "run code",
      parameters: {
        language: { type: "string", required: true },
        code: { type: "string", required: true },
      },
      execute: async ({ language, code }) => ({ language, code }),
    });

    const registry = new InMemoryToolRegistry([searchTool, codeTool]);
    const builder = new PromptBuilder(registry);
    const context = [
      { content: "previous conversation" },
      { content: "system note" },
    ];
    const prompt = builder.build("Write a summary", context);

    expect(prompt).toBe(
      buildExpectedPrompt({
        tools: registry.getAvailableTools(),
        context,
        userPrompt: "Write a summary",
      }),
    );
  });

  it("handles empty tool and context lists", () => {
    const registry = new InMemoryToolRegistry();
    const builder = new PromptBuilder(registry);

    expect(builder.build("Hello there")).toBe(
      buildExpectedPrompt({
        tools: registry.getAvailableTools(),
        context: [],
        userPrompt: "Hello there",
      }),
    );
  });

  it("reflects runtime tool registry updates without caching results", () => {
    const registry = new InMemoryToolRegistry();
    const builder = new PromptBuilder(registry);

    const planTool = createTool({
      name: "planner",
      description: "plan tasks",
      parameters: {
        topic: { type: "string", required: true },
      },
      execute: async ({ topic }) => ({ plan: `Plan for ${topic}` }),
    });

    registry.register(planTool);
    const firstToolSnapshot = registry.getAvailableTools();
    const firstPrompt = builder.build("Organize the day");

    expect(firstPrompt).toBe(
      buildExpectedPrompt({
        tools: firstToolSnapshot,
        context: [],
        userPrompt: "Organize the day",
      }),
    );

    const summaryTool = createTool({
      name: "summarizer",
      description: "summarize notes",
      parameters: {
        notes: { type: "string", required: true },
      },
      execute: async ({ notes }) => ({ summary: notes.slice(0, 10) }),
    });

    registry.register(summaryTool);
    const secondToolSnapshot = registry.getAvailableTools();
    const secondPrompt = builder.build("Organize the day");

    expect(secondPrompt).toBe(
      buildExpectedPrompt({
        tools: secondToolSnapshot,
        context: [],
        userPrompt: "Organize the day",
      }),
    );
    expect(firstPrompt).not.toContain("summarize notes");
  });

  it("incorporates conversation history and executed tool output", async () => {
    const registry = new InMemoryToolRegistry();
    const builder = new PromptBuilder(registry);

    const doublerTool = createTool({
      name: "doubler",
      description: "double numeric strings",
      parameters: {
        value: { type: "number", required: true },
      },
      execute: async ({ value }) => {
        const numeric = Number(value);
        return { doubled: numeric * 2 };
      },
    });

    registry.register(doublerTool);

    const toolHandler = new ToolHandler(registry);
    const llmResponse = 'TOOL_CALL:doubler(value="21")';
    const calls = toolHandler.parse(llmResponse);
    const toolResults = await toolHandler.execute(calls);

    const conversation = [
      { role: "user", content: "How do I double 21?" },
      { role: "assistant", content: "Let me calculate that." },
    ];
    const prompt = builder.build("Share the doubled result", [
      ...conversation,
      ...toolResults,
    ]);

    expect(prompt).toBe(
      buildExpectedPrompt({
        tools: registry.getAvailableTools(),
        context: [...conversation, ...toolResults],
        userPrompt: "Share the doubled result",
      }),
    );
    expect(prompt).toContain('{"doubled":42}');
  });
});
