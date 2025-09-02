export default class ToolHandler {
  constructor(toolRegistry) {
    this.toolRegistry = toolRegistry;
    this.callRegex = /TOOL_CALL: (\w+) \((.+)\)/g;
  }

  parse(response) {
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

  async execute(calls) {
    const results = [];
    for (const { name, args } of calls) {
      const tool = this.toolRegistry.getTool(name);
      if (!tool) continue;
      try {
        const res = await tool.execute(args);
        results.push({ role: "tool", name, content: JSON.stringify(res) });
      } catch (error) {
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
