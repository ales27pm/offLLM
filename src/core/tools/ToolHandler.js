import logger from "../../utils/logger";

const getArgKeys = (args) =>
  args && typeof args === "object" ? Object.keys(args) : [];

export default class ToolHandler {
  constructor(toolRegistry) {
    this.toolRegistry = toolRegistry;
    this.callRegex = /TOOL_CALL:\s*(\w+)\s*\(([\s\S]*?)\)/g;
  }

  parse(response) {
    this.callRegex.lastIndex = 0;
    const matches = [...response.matchAll(this.callRegex)];
    return matches.map(([, name, args]) => ({
      name,
      args: this._parseArgs(args),
    }));
  }

  _parseArgs(argString) {
    const args = {};
    const regex =
      /([\w]+)=('([^'\\]*(\\.[^'\\]*)*)'|"([^"\\]*(\\.[^"\\]*)*)")/g;
    let match;
    while ((match = regex.exec(argString)) !== null) {
      let value = match[3] !== undefined ? match[3] : match[5];
      value = value.replace(/\\(['"\\])/g, "$1");
      const trimmed = value.trim();
      try {
        if (
          (trimmed.startsWith("{") && trimmed.endsWith("}")) ||
          (trimmed.startsWith("[") && trimmed.endsWith("]"))
        ) {
          args[match[1]] = JSON.parse(trimmed);
        } else {
          args[match[1]] = value;
        }
      } catch {
        throw new Error("Malformed argument string: " + argString);
      }
    }
    const expected = (argString.match(/([\w]+)=('|")/g) || []).length;
    if (Object.keys(args).length !== expected) {
      throw new Error("Malformed argument string: " + argString);
    }
    return args;
  }

  async execute(calls, options = {}) {
    const results = [];
    const { tracer } = options;
    for (const { name, args } of calls) {
      const tool = this.toolRegistry.getTool(name);
      if (!tool) {
        if (tracer && typeof tracer.warn === "function") {
          tracer.warn(`Unknown tool requested: ${name}`, { tool: name });
        }
        logger.warn("ToolHandler", `Tool ${name} is not registered`, {
          tool: name,
        });
        continue;
      }
      const step =
        tracer && typeof tracer.startStep === "function"
          ? tracer.startStep(`tool:${name}`, {
              tool: name,
              argKeys: getArgKeys(args),
            })
          : null;
      try {
        const res = await tool.execute(args);
        if (step && tracer && typeof tracer.endStep === "function") {
          tracer.endStep(step, {
            tool: name,
            resultType: typeof res,
          });
        }
        results.push({ role: "tool", name, content: JSON.stringify(res) });
      } catch (error) {
        if (step && tracer && typeof tracer.failStep === "function") {
          tracer.failStep(step, error, { tool: name });
        }
        logger.error("ToolHandler", `Tool ${name} execution failed`, error, {
          tool: name,
          argKeys: getArgKeys(args),
        });
        results.push({
          role: "tool",
          name,
          content: `Error: ${error.message}`,
        });
      }
    }
    return results;
  }
}
