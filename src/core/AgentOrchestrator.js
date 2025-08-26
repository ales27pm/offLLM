import LLMService from "../services/llmService";
import { toolRegistry } from "./tools/ToolRegistry";
import MemoryManager from "./memory/MemoryManager";
import PluginSystem from "./plugins/PluginSystem";

export class AgentOrchestrator {
  constructor() {
    this.llm = LLMService;
    this.memory = new MemoryManager();
    this.plugins = new PluginSystem();
    this.plugins.loadPlugins();
  }

  async run(prompt, context = {}) {
    const longTermMemory = await this.memory.retrieve(prompt);
    const shortTermMemory = this.memory.getConversationHistory();

    const fullContext = [...longTermMemory, ...shortTermMemory];
    const augmentedPrompt = this._augmentPrompt(prompt, fullContext);

    const initial = await this.llm.generate(augmentedPrompt);
    const rawResponse = initial.text ?? initial;

    const toolCalls = this._parseToolCalls(rawResponse);
    if (toolCalls.length > 0) {
      const toolResults = await this._executeToolCalls(toolCalls);
      const finalPrompt = this._augmentPrompt(prompt, [
        ...fullContext,
        ...toolResults,
      ]);
      const final = await this.llm.generate(finalPrompt);
      const finalText = final.text ?? final;
      this.memory.addInteraction(prompt, finalText, toolResults);
      return finalText;
    }

    this.memory.addInteraction(prompt, rawResponse);
    return rawResponse;
  }

  _augmentPrompt(prompt, context) {
    const contextStr = context.map((c) => c.content).join("\n");
    const toolsStr = toolRegistry
      .getAvailableTools()
      .map(
        (t) =>
          `Tool: ${t.name} - ${t.description} (Params: ${JSON.stringify(
            t.parameters
          )})`
      )
      .join("\n");

    return `\nYou are an AI assistant with access to the following tools:\n${toolsStr}\n\nCurrent context:\n${contextStr}\n\nUser: ${prompt}\nAssistant:`;
  }

  _parseToolCalls(response) {
    const toolCallRegex = /TOOL_CALL: (\w+) \((.+)\)/g;
    const matches = [...response.matchAll(toolCallRegex)];
    return matches.map((match) => ({
      name: match[1],
      args: this._parseArgs(match[2]),
    }));
  }

  _parseArgs(argString) {
    const args = {};
    const regex = /(\w+)='([^']+)'/g;
    let match;
    while ((match = regex.exec(argString)) !== null) {
      args[match[1]] = match[2];
    }
    return args;
  }

  async _executeToolCalls(toolCalls) {
    const results = [];
    for (const call of toolCalls) {
      const tool = toolRegistry.getTool(call.name);
      if (tool) {
        try {
          const result = await tool.execute(call.args);
          results.push({
            role: "tool",
            name: call.name,
            content: JSON.stringify(result),
          });
        } catch (error) {
          results.push({
            role: "tool",
            name: call.name,
            content: `Error: ${error.message}`,
          });
        }
      }
    }
    return results;
  }
}

export default AgentOrchestrator;
