import LLMService from "../services/llmService";
import { toolRegistry } from "./tools/ToolRegistry";
import MemoryManager from "./memory/MemoryManager";
import PluginSystem from "./plugins/PluginSystem";
import PromptBuilder from "./prompt/PromptBuilder";
import ToolHandler from "./tools/ToolHandler";

export class AgentOrchestrator {
  constructor() {
    this.llm = LLMService;
    this.memory = new MemoryManager();
    this.promptBuilder = new PromptBuilder(toolRegistry);
    this.toolHandler = new ToolHandler(toolRegistry);
    this.plugins = new PluginSystem();
    this.plugins.loadPlugins();
  }

  async run(prompt, context = {}) {
    const longMem = await this.memory.retrieve(prompt);
    const shortMem = this.memory.getConversationHistory();
    const fullCtx = [...longMem, ...shortMem];

    const initialPrompt = this.promptBuilder.build(prompt, fullCtx);
    const initial = await this.llm.generate(initialPrompt);
    const initialText = initial.text ?? initial;
    const calls = this.toolHandler.parse(initialText);

    if (!calls.length) {
      this.memory.addInteraction(prompt, initialText);
      return initialText;
    }

    const toolResults = await this.toolHandler.execute(calls);
    const finalPrompt = this.promptBuilder.build(prompt, [
      ...fullCtx,
      ...toolResults,
    ]);
    const final = await this.llm.generate(finalPrompt);
    const finalText = final.text ?? final;

    this.memory.addInteraction(prompt, finalText, toolResults);
    return finalText;
  }
}

export default AgentOrchestrator;
