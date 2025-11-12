import LLMService from "../services/llmService";
import { toolRegistry } from "./tools/ToolRegistry";
import MemoryManager from "./memory/MemoryManager";
import SessionNoteManager from "./memory/SessionNoteManager";
import PluginSystem from "./plugins/PluginSystem";
import PromptBuilder from "./prompt/PromptBuilder";
import ToolHandler from "./tools/ToolHandler";
import { WorkflowTracer } from "./workflows/WorkflowTracer";

const WORKFLOW_NAME = "AgentOrchestrator";

const normalizeModelOutput = (result) => {
  if (typeof result === "string") {
    return result;
  }
  if (result && typeof result.text === "string") {
    return result.text;
  }
  if (result === undefined || result === null) {
    return "";
  }
  return String(result);
};

const promptLength = (value) =>
  typeof value === "string" ? value.length : normalizeModelOutput(value).length;

export class AgentOrchestrator {
  constructor() {
    this.llm = LLMService;
    this.memory = new MemoryManager();
    this.sessionNotes = new SessionNoteManager();
    this.promptBuilder = new PromptBuilder(toolRegistry);
    this.toolHandler = new ToolHandler(toolRegistry);
    this.plugins = new PluginSystem();
    this.plugins.loadPlugins();
  }

  async run(prompt) {
    const tracer = new WorkflowTracer({ workflowName: WORKFLOW_NAME });
    tracer.info("Workflow started", {
      promptLength: promptLength(prompt),
      promptPreview: tracer.preview(typeof prompt === "string" ? prompt : ""),
    });

    try {
      const sessionNoteEntries = await tracer.withStep(
        "retrieveSessionNotes",
        () => this.sessionNotes.getContextEntries(),
        {
          successData: (entries) => ({ records: entries.length }),
        },
      );

      const longMem = await tracer.withStep(
        "retrieveLongTermMemory",
        () => this.memory.retrieve(prompt),
        {
          startData: { promptLength: promptLength(prompt) },
          successData: (entries) => ({ records: entries.length }),
        },
      );

      const shortMem = await tracer.withStep(
        "conversationHistory",
        () => Promise.resolve(this.memory.getConversationHistory()),
        {
          successData: (entries) => ({ records: entries.length }),
        },
      );

      const fullCtx = [...sessionNoteEntries, ...longMem, ...shortMem];
      tracer.debug("Context assembled", {
        notes: sessionNoteEntries.length,
        longTerm: longMem.length,
        shortTerm: shortMem.length,
        total: fullCtx.length,
      });

      const initialPrompt = await tracer.withStep(
        "buildInitialPrompt",
        () => Promise.resolve(this.promptBuilder.build(prompt, fullCtx)),
        {
          successData: (value) => ({
            length: typeof value === "string" ? value.length : 0,
            preview:
              typeof value === "string" ? tracer.preview(value) : undefined,
          }),
        },
      );

      const initial = await tracer.withStep(
        "initialModelCall",
        () => this.llm.generate(initialPrompt),
        {
          successData: (response) => {
            const text = normalizeModelOutput(response);
            return {
              length: text.length,
              preview: tracer.preview(text),
            };
          },
        },
      );

      const initialText = normalizeModelOutput(initial);
      tracer.debug("Initial model response normalized", {
        length: initialText.length,
      });

      const calls = this.toolHandler.parse(initialText);
      tracer.info("Parsed tool calls", {
        count: calls.length,
        toolNames: calls.map((call) => call.name),
      });

      if (!calls.length) {
        tracer.info("No tool calls detected", {
          responseLength: initialText.length,
        });
        await tracer.withStep(
          "persistMemory",
          () => this.memory.addInteraction(prompt, initialText, []),
          {
            successData: () => ({ toolResults: 0 }),
          },
        );
        tracer.finish({
          toolResults: 0,
          finalResponseLength: initialText.length,
          finalPreview: tracer.preview(initialText),
        });
        return initialText;
      }

      const toolResults = await tracer.withStep(
        "executeTools",
        () => this.toolHandler.execute(calls, { tracer }),
        {
          successData: (results) => ({
            count: results.length,
            toolNames: results.map((result) => result.name),
          }),
        },
      );

      const finalPrompt = await tracer.withStep(
        "buildFinalPrompt",
        () =>
          Promise.resolve(
            this.promptBuilder.build(prompt, [...fullCtx, ...toolResults]),
          ),
        {
          successData: (value) => ({
            length: typeof value === "string" ? value.length : 0,
            preview:
              typeof value === "string" ? tracer.preview(value) : undefined,
          }),
        },
      );

      const final = await tracer.withStep(
        "finalModelCall",
        () => this.llm.generate(finalPrompt),
        {
          successData: (response) => {
            const text = normalizeModelOutput(response);
            return {
              length: text.length,
              preview: tracer.preview(text),
            };
          },
        },
      );

      const finalText = normalizeModelOutput(final);
      tracer.info("Final model response ready", {
        length: finalText.length,
        preview: tracer.preview(finalText),
      });

      await tracer.withStep(
        "persistMemory",
        () => this.memory.addInteraction(prompt, finalText, toolResults),
        {
          successData: () => ({ toolResults: toolResults.length }),
        },
      );

      tracer.finish({
        toolResults: toolResults.length,
        finalResponseLength: finalText.length,
        finalPreview: tracer.preview(finalText),
      });

      return finalText;
    } catch (error) {
      tracer.fail(error, { promptLength: promptLength(prompt) });
      await this.sessionNotes.recordError(error, {
        source: WORKFLOW_NAME,
        promptLength: promptLength(prompt),
      });
      throw error;
    }
  }
}

export default AgentOrchestrator;
