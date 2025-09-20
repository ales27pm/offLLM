import { searchService } from "../services/webSearchService";
import { validate as validateSearchApiKeys } from "../services/utils/apiKeys";

const DEFAULT_PROVIDER = "google";
const DEFAULT_TIME_RANGE = "any";
const DEFAULT_MAX_RESULTS = 5;
const MAX_RESULTS_CAP = 20;
const DEFAULT_SAFE_SEARCH = true;
const SUPPORTED_PROVIDERS = new Set(["google", "bing", "duckduckgo", "brave"]);
const SUPPORTED_TIME_RANGES = new Set(["day", "week", "month", "year", "any"]);

const isReactNative =
  typeof navigator !== "undefined" && navigator.product === "ReactNative";

let RNFS = null;
let nodeFs = null;
let nodePath = null;
let nodeModulesLoaded = false;
let nodeFsWarningLogged = false;

if (isReactNative) {
  try {
    RNFS = require("react-native-fs");
  } catch (error) {
    console.warn(
      "[toolSystem] Failed to load react-native-fs; file system operations will be limited.",
      error,
    );
    RNFS = null;
  }
}

const FS_MODULE_ID = ["f", "s"].join("");
const PATH_MODULE_ID = ["p", "a", "t", "h"].join("");

const resolveNodeRequire = () => {
  if (typeof globalThis === "object") {
    const nonWebpackRequire = globalThis.__non_webpack_require__;
    if (typeof nonWebpackRequire === "function") {
      return nonWebpackRequire;
    }
  }

  if (typeof module !== "undefined" && typeof module.require === "function") {
    return module.require.bind(module);
  }

  if (typeof require === "function") {
    return require;
  }

  try {
    return Function("return require")();
  } catch {
    return null;
  }
};

const logNodeFsUnavailable = (error) => {
  if (!nodeFsWarningLogged) {
    console.warn(
      "[toolSystem] Node fs.promises is unavailable; file system tool cannot access the local disk.",
      error,
    );
    nodeFsWarningLogged = true;
  }
};

const loadNodeModulesIfNeeded = () => {
  if (nodeModulesLoaded) {
    return;
  }
  nodeModulesLoaded = true;

  if (isReactNative) {
    nodeFs = null;
    nodePath = null;
    return;
  }

  const requireFn = resolveNodeRequire();
  if (!requireFn) {
    nodeFs = null;
    nodePath = null;
    logNodeFsUnavailable();
    return;
  }

  try {
    const fsModule = requireFn(FS_MODULE_ID);
    nodeFs = fsModule && fsModule.promises ? fsModule.promises : null;
    if (!nodeFs) {
      logNodeFsUnavailable();
    }
  } catch (error) {
    nodeFs = null;
    logNodeFsUnavailable(error);
  }

  try {
    nodePath = requireFn(PATH_MODULE_ID) || null;
  } catch {
    nodePath = null;
  }
};

const getNodeFs = () => {
  loadNodeModulesIfNeeded();
  return nodeFs;
};

const getNodePath = () => {
  loadNodeModulesIfNeeded();
  return nodePath;
};

const hasOwn = (object, key) =>
  object != null && Object.prototype.hasOwnProperty.call(object, key);

const toTrimmedString = (value) =>
  typeof value === "string" ? value.trim() : "";

const toIsoDateString = (value) => {
  if (!value) {
    return null;
  }
  const date =
    value instanceof Date
      ? value
      : typeof value === "number" || typeof value === "string"
        ? new Date(value)
        : null;
  if (date && !Number.isNaN(date.getTime())) {
    return date.toISOString();
  }
  return null;
};

const pathDirname = (targetPath) => {
  if (!targetPath) {
    return "";
  }
  const nodePathModule = getNodePath();
  if (nodePathModule) {
    return nodePathModule.dirname(targetPath);
  }
  const normalised = targetPath.replace(/\\+/g, "/");
  const index = normalised.lastIndexOf("/");
  if (index <= 0) {
    return normalised.startsWith("/") ? "/" : "";
  }
  return normalised.slice(0, index);
};

const joinPath = (base, segment) => {
  const nodePathModule = getNodePath();
  if (nodePathModule) {
    return nodePathModule.join(base, segment);
  }
  if (!base) {
    return segment;
  }
  const trimmed = base.replace(/[\\/]+$/, "");
  return `${trimmed}/${segment}`;
};

const ensureDirectoryExists = async (filePath) => {
  const directory = pathDirname(filePath);
  if (
    !directory ||
    directory === "." ||
    directory === filePath ||
    directory === "/"
  ) {
    return;
  }
  if (RNFS) {
    const exists = await RNFS.exists(directory);
    if (!exists) {
      await RNFS.mkdir(directory);
    }
    return;
  }
  const nodeFsModule = getNodeFs();
  if (nodeFsModule) {
    await nodeFsModule.mkdir(directory, { recursive: true });
  }
};

const getPathStats = async (targetPath) => {
  if (RNFS) {
    try {
      return await RNFS.stat(targetPath);
    } catch {
      return null;
    }
  }

  const nodeFsModule = getNodeFs();
  if (nodeFsModule) {
    try {
      return await nodeFsModule.stat(targetPath);
    } catch {
      return null;
    }
  }

  return null;
};

const pathExists = async (targetPath) =>
  Boolean(await getPathStats(targetPath));

const isDirectoryStat = (stats) => {
  if (!stats) {
    return false;
  }
  if (typeof stats.isDirectory === "function") {
    return stats.isDirectory();
  }
  if (typeof stats.isDirectory === "boolean") {
    return stats.isDirectory;
  }
  return false;
};

const resolveOptionValue = (
  key,
  {
    originalParameters = {},
    contextOptions = {},
    parameterValues = {},
    fallback,
  },
) => {
  if (hasOwn(parameterValues, key)) {
    return parameterValues[key];
  }
  if (hasOwn(contextOptions, key)) {
    return contextOptions[key];
  }
  if (hasOwn(originalParameters, key)) {
    return originalParameters[key];
  }
  return fallback;
};

const matchesType = (expectedType, value) => {
  switch (expectedType) {
    case "string":
      return typeof value === "string";
    case "number":
      return typeof value === "number" && !Number.isNaN(value);
    case "boolean":
      return typeof value === "boolean";
    case "array":
      return Array.isArray(value);
    case "object":
      return (
        value !== null && typeof value === "object" && !Array.isArray(value)
      );
    default:
      return true;
  }
};

const normalizeProvider = (value) => {
  if (typeof value !== "string") {
    return DEFAULT_PROVIDER;
  }
  const normalised = value.trim().toLowerCase();
  if (SUPPORTED_PROVIDERS.has(normalised)) {
    return normalised;
  }
  return DEFAULT_PROVIDER;
};

const normalizeTimeRange = (value) => {
  if (typeof value !== "string") {
    return DEFAULT_TIME_RANGE;
  }
  const normalised = value.trim().toLowerCase();
  if (SUPPORTED_TIME_RANGES.has(normalised)) {
    return normalised;
  }
  return DEFAULT_TIME_RANGE;
};

const normalizeSafeSearch = (value) => {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const trimmed = value.trim().toLowerCase();
    if (trimmed === "true") {
      return true;
    }
    if (trimmed === "false") {
      return false;
    }
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  return DEFAULT_SAFE_SEARCH;
};

const normalizeMaxResults = (value) => {
  const numeric =
    typeof value === "number" && !Number.isNaN(value)
      ? value
      : typeof value === "string" && value.trim() !== ""
        ? Number(value)
        : DEFAULT_MAX_RESULTS;
  if (!Number.isFinite(numeric)) {
    return DEFAULT_MAX_RESULTS;
  }
  const integer = Math.floor(numeric);
  if (integer < 1) {
    return 1;
  }
  if (integer > MAX_RESULTS_CAP) {
    return MAX_RESULTS_CAP;
  }
  return integer;
};

const normalizeSearchResults = (results, limit) => {
  if (!Array.isArray(results)) {
    return [];
  }

  return results
    .map((item) => {
      if (!item || typeof item !== "object") {
        return null;
      }
      const title =
        toTrimmedString(item.title) ||
        toTrimmedString(item.name) ||
        toTrimmedString(item.url);
      const url = toTrimmedString(item.url);
      const snippet =
        toTrimmedString(item.snippet) ||
        toTrimmedString(item.description) ||
        toTrimmedString(item.content);

      if (!title && !url && !snippet) {
        return null;
      }

      return {
        title,
        url,
        snippet,
      };
    })
    .filter(Boolean)
    .slice(0, limit);
};

const normalizeDirectoryEntriesFromRN = (entries) =>
  entries.map((entry) => ({
    name: entry.name,
    path: entry.path,
    isFile:
      typeof entry.isFile === "function"
        ? entry.isFile()
        : Boolean(entry.isFile),
    isDirectory:
      typeof entry.isDirectory === "function"
        ? entry.isDirectory()
        : Boolean(entry.isDirectory),
    size:
      typeof entry.size === "number" && Number.isFinite(entry.size)
        ? entry.size
        : null,
    modifiedAt: toIsoDateString(entry.mtime),
  }));

const listNodeDirectory = async (directoryPath) => {
  const nodeFsModule = getNodeFs();
  if (!nodeFsModule) {
    throw new Error("Node file system is not available");
  }
  const dirents = await nodeFsModule.readdir(directoryPath, {
    withFileTypes: true,
  });
  const entries = await Promise.all(
    dirents.map(async (dirent) => {
      const entryPath = joinPath(directoryPath, dirent.name);
      let stats = null;
      try {
        stats = await nodeFsModule.stat(entryPath);
      } catch {
        stats = null;
      }
      return {
        name: dirent.name,
        path: entryPath,
        isFile: dirent.isFile(),
        isDirectory: dirent.isDirectory(),
        size: stats ? stats.size : null,
        modifiedAt: stats ? toIsoDateString(stats.mtime) : null,
      };
    }),
  );
  return entries;
};

export class ToolRegistry {
  constructor() {
    this.tools = new Map();
    this.toolCategories = new Map();
    this.executionHistory = [];
  }

  registerTool(toolName, toolDefinition, category = "general") {
    if (!this.toolCategories.has(category)) {
      this.toolCategories.set(category, new Set());
    }

    this.tools.set(toolName, {
      ...toolDefinition,
      category,
      lastUsed: null,
      usageCount: 0,
    });

    this.toolCategories.get(category).add(toolName);
  }

  async executeTool(toolName, parameters, context = {}) {
    const tool = this.tools.get(toolName);
    if (!tool) {
      throw new Error(`Tool ${toolName} not found`);
    }

    const normalizedParameters = this.applyParameterDefaults(
      tool,
      parameters && typeof parameters === "object" ? parameters : {},
    );

    try {
      // Validate parameters
      this.validateParameters(tool, normalizedParameters);

      // Execute the tool
      const executionContext =
        context && typeof context === "object" ? { ...context } : {};
      if (!hasOwn(executionContext, "originalParameters")) {
        executionContext.originalParameters =
          parameters && typeof parameters === "object" ? parameters : {};
      }

      const result = await tool.execute(normalizedParameters, executionContext);

      // Update tool usage statistics
      tool.lastUsed = new Date();
      tool.usageCount = (tool.usageCount || 0) + 1;

      const summarize = (r) => {
        if (!r || typeof r !== "object") {
          return r;
        }
        const summary = { success: !!r.success };
        if (typeof r.error === "string") {
          summary.error = r.error.slice(0, 200);
        }
        if (Array.isArray(r.results)) {
          summary.resultCount = r.results.length;
        }
        if (Array.isArray(r.entries)) {
          summary.resultCount = r.entries.length;
        }
        if (typeof r.bytesWritten === "number") {
          summary.bytesWritten = r.bytesWritten;
        }
        if (typeof r.bytesRead === "number") {
          summary.bytesRead = r.bytesRead;
        }
        return summary;
      };

      // Log execution
      this.executionHistory.push({
        tool: toolName,
        parameters: normalizedParameters,
        result: summarize(result),
        timestamp: new Date(),
        success: true,
        ...(this.extractResultAnalytics(result) || {}),
      });

      return result;
    } catch (error) {
      this.executionHistory.push({
        tool: toolName,
        parameters: normalizedParameters,
        error: error.message,
        timestamp: new Date(),
        success: false,
      });

      throw error;
    }
  }

  applyParameterDefaults(tool, parameters = {}) {
    if (!tool.parameters) {
      return { ...parameters };
    }

    const resolved = { ...parameters };
    for (const [paramName, paramConfig] of Object.entries(tool.parameters)) {
      if (resolved[paramName] === undefined && hasOwn(paramConfig, "default")) {
        resolved[paramName] =
          typeof paramConfig.default === "function"
            ? paramConfig.default()
            : paramConfig.default;
      }
    }
    return resolved;
  }

  extractResultAnalytics(result) {
    if (!result || typeof result !== "object") {
      return null;
    }
    if (Array.isArray(result.results)) {
      return { resultCount: result.results.length };
    }
    if (Array.isArray(result.entries)) {
      return { resultCount: result.entries.length };
    }
    return null;
  }

  validateParameters(tool, parameters = {}) {
    if (tool.parameters) {
      for (const [paramName, paramConfig] of Object.entries(tool.parameters)) {
        const hasValue = hasOwn(parameters, paramName);
        if (paramConfig.required && !hasValue) {
          throw new Error(`Missing required parameter: ${paramName}`);
        }

        if (!hasValue) {
          continue;
        }

        const value = parameters[paramName];

        if (paramConfig.type && !matchesType(paramConfig.type, value)) {
          throw new Error(
            `Invalid type for parameter ${paramName}: expected ${paramConfig.type}`,
          );
        }

        if (paramConfig.enum && !paramConfig.enum.includes(value)) {
          throw new Error(
            `Invalid value for parameter: ${paramName}. Expected one of ${paramConfig.enum.join(", ")}`,
          );
        }

        if (paramConfig.validate && !paramConfig.validate(value)) {
          throw new Error(`Invalid value for parameter: ${paramName}`);
        }
      }
    }
  }

  getToolsByCategory(category) {
    return Array.from(this.toolCategories.get(category) || []).map((toolName) =>
      this.tools.get(toolName),
    );
  }

  getMostUsedTools(limit = 10) {
    return Array.from(this.tools.values())
      .sort((a, b) => (b.usageCount || 0) - (a.usageCount || 0))
      .slice(0, limit);
  }

  suggestTools(query) {
    // Simple tool suggestion based on name and description matching
    const queryLower = query.toLowerCase();

    return Array.from(this.tools.entries())
      .map(([name, tool]) => {
        let score = 0;

        // Name match
        if (name.toLowerCase().includes(queryLower)) {
          score += 3;
        }

        // Description match
        if (
          tool.description &&
          tool.description.toLowerCase().includes(queryLower)
        ) {
          score += 2;
        }

        // Category match
        if (tool.category && tool.category.toLowerCase().includes(queryLower)) {
          score += 1;
        }

        // Recent usage bonus
        if (tool.lastUsed && Date.now() - tool.lastUsed < 24 * 60 * 60 * 1000) {
          score += 0.5;
        }

        return { name, tool, score };
      })
      .filter((item) => item.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((item) => item.name);
  }
}

export class MCPClient {
  constructor(serverUrl, options = {}) {
    this.serverUrl = serverUrl;
    this.options = {
      timeout: 30000,
      autoReconnect: true,
      reconnectDelay: 2000,
      maxReconnectAttempts: 5,
      ...options,
    };
    this.connected = false;
    this.reconnectAttempts = 0;
    this.messageId = 0;
    this.pendingRequests = new Map();
    this.ws = null;
    this.messageQueue = [];
  }

  async connect() {
    return new Promise((resolve, reject) => {
      if (this.connected) {
        resolve();
        return;
      }

      try {
        this.ws = new WebSocket(this.serverUrl);

        this.ws.onopen = () => {
          this.connected = true;
          this.reconnectAttempts = 0;
          console.log("MCP client connected to:", this.serverUrl);

          // Process any queued messages
          this.processMessageQueue();

          resolve();
        };

        this.ws.onmessage = (event) => {
          try {
            const response = JSON.parse(event.data);
            this.handleResponse(response);
          } catch (error) {
            console.error("Failed to parse MCP response:", error);
          }
        };

        this.ws.onclose = (event) => {
          this.connected = false;
          console.log("MCP connection closed:", event.code, event.reason);

          if (
            this.options.autoReconnect &&
            this.reconnectAttempts < this.options.maxReconnectAttempts
          ) {
            setTimeout(() => {
              this.reconnectAttempts++;
              console.log(`Reconnecting attempt ${this.reconnectAttempts}...`);
              this.connect().catch(console.error);
            }, this.options.reconnectDelay);
          }
        };

        this.ws.onerror = (error) => {
          console.error("MCP WebSocket error:", error);
          reject(error);
        };
      } catch (error) {
        console.error("MCP connection failed:", error);
        reject(error);
      }
    });
  }

  async callTool(toolName, parameters) {
    if (!this.connected) {
      await this.connect();
    }

    const messageId = this.messageId++;
    const request = {
      jsonrpc: "2.0",
      id: messageId,
      method: "tools/call",
      params: {
        name: toolName,
        arguments: parameters,
      },
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(messageId);
        reject(new Error("MCP request timeout"));
      }, this.options.timeout);

      this.pendingRequests.set(messageId, { resolve, reject, timeout });

      this.sendRequest(request);
    });
  }

  async listTools() {
    if (!this.connected) {
      await this.connect();
    }

    const messageId = this.messageId++;
    const request = {
      jsonrpc: "2.0",
      id: messageId,
      method: "tools/list",
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(messageId);
        reject(new Error("MCP request timeout"));
      }, this.options.timeout);

      this.pendingRequests.set(messageId, { resolve, reject, timeout });
      this.sendRequest(request);
    });
  }

  sendRequest(request) {
    if (this.connected && this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(request));
    } else {
      // Queue the message if not connected
      this.messageQueue.push(request);
      if (!this.connected) {
        this.connect().catch(console.error);
      }
    }
  }

  processMessageQueue() {
    while (this.messageQueue.length > 0 && this.connected) {
      const request = this.messageQueue.shift();
      this.ws.send(JSON.stringify(request));
    }
  }

  handleResponse(response) {
    const pending = this.pendingRequests.get(response.id);
    if (!pending) return;

    clearTimeout(pending.timeout);
    this.pendingRequests.delete(response.id);

    if (response.error) {
      pending.reject(new Error(response.error.message || "MCP error"));
    } else {
      pending.resolve(response.result);
    }
  }

  disconnect() {
    this.options.autoReconnect = false;
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.connected = false;

    // Reject all pending requests
    for (const [_id, pending] of this.pendingRequests) {
      clearTimeout(pending.timeout);
      pending.reject(new Error("MCP connection closed"));
    }
    this.pendingRequests.clear();
  }
}

// Example tool implementations
export const builtInTools = {
  calculator: {
    description: "Perform mathematical calculations",
    parameters: {
      expression: {
        type: "string",
        required: true,
        description: "Mathematical expression to evaluate",
      },
    },
    execute: async (parameters) => {
      try {
        // Safe evaluation of mathematical expressions
        const result = eval(
          parameters.expression.replace(/[^0-9+\-*/().]/g, ""),
        );
        return { result, success: true };
      } catch (error) {
        return { error: error.message, success: false };
      }
    },
  },

  webSearch: {
    description: "Search the web for information",
    parameters: {
      query: {
        type: "string",
        required: true,
        description: "Search query",
      },
      maxResults: {
        type: "number",
        required: false,
        description: "Maximum number of results to return",
        default: DEFAULT_MAX_RESULTS,
        validate: (value) =>
          Number.isInteger(value) && value > 0 && value <= MAX_RESULTS_CAP,
      },
      provider: {
        type: "string",
        required: false,
        description: "Search provider to use",
        enum: Array.from(SUPPORTED_PROVIDERS),
      },
      timeRange: {
        type: "string",
        required: false,
        description: "Time range for results",
        enum: Array.from(SUPPORTED_TIME_RANGES),
      },
      safeSearch: {
        type: "boolean",
        required: false,
        description: "Enable safe search filtering",
      },
    },
    execute: async (parameters, context = {}) => {
      const originalParameters =
        context && typeof context.originalParameters === "object"
          ? context.originalParameters
          : {};
      const contextOptions =
        context && typeof context.webSearch === "object"
          ? context.webSearch
          : {};

      const provider = normalizeProvider(
        resolveOptionValue("provider", {
          originalParameters,
          contextOptions,
          parameterValues: parameters,
          fallback: DEFAULT_PROVIDER,
        }),
      );

      const timeRange = normalizeTimeRange(
        resolveOptionValue("timeRange", {
          originalParameters,
          contextOptions,
          parameterValues: parameters,
          fallback: DEFAULT_TIME_RANGE,
        }),
      );

      const safeSearch = normalizeSafeSearch(
        resolveOptionValue("safeSearch", {
          originalParameters,
          contextOptions,
          parameterValues: parameters,
          fallback: DEFAULT_SAFE_SEARCH,
        }),
      );

      const maxResults = normalizeMaxResults(
        resolveOptionValue("maxResults", {
          originalParameters,
          contextOptions,
          parameterValues: parameters,
          fallback: DEFAULT_MAX_RESULTS,
        }),
      );

      try {
        const hasValidKey = await validateSearchApiKeys(provider);
        if (!hasValidKey) {
          throw new Error(`API key not configured for ${provider} search`);
        }

        const searchResults = await searchService.performSearch(
          provider,
          parameters.query,
          maxResults,
          timeRange,
          safeSearch,
        );

        const normalizedResults = normalizeSearchResults(
          searchResults,
          maxResults,
        );

        return {
          success: true,
          provider,
          query: parameters.query,
          timeRange,
          safeSearch,
          resultCount: normalizedResults.length,
          results: normalizedResults,
        };
      } catch (error) {
        console.error("Web search failed:", error);
        return {
          success: false,
          provider,
          query: parameters.query,
          timeRange,
          safeSearch,
          error: error.message,
        };
      }
    },
  },

  fileSystem: {
    description: "Read from and write to the file system",
    parameters: {
      operation: {
        type: "string",
        required: true,
        enum: ["read", "write", "list"],
        description: "File system operation to perform",
      },
      path: {
        type: "string",
        required: true,
        description: "File or directory path",
      },
      content: {
        type: "string",
        required: false,
        description: "Content to write (for write operations )",
      },
    },
    execute: async (parameters) => {
      const { operation, path: targetPath, content } = parameters;
      const nodeFsModule = getNodeFs();

      try {
        if (!targetPath || typeof targetPath !== "string") {
          throw new Error(
            "A valid path is required for file system operations",
          );
        }

        switch (operation) {
          case "read": {
            if (!(await pathExists(targetPath))) {
              throw new Error(`File not found at ${targetPath}`);
            }

            if (RNFS) {
              const data = await RNFS.readFile(targetPath, "utf8");
              return {
                success: true,
                operation,
                path: targetPath,
                content: data,
                bytesRead: typeof data === "string" ? data.length : undefined,
              };
            }

            if (nodeFsModule) {
              const data = await nodeFsModule.readFile(targetPath, "utf8");
              return {
                success: true,
                operation,
                path: targetPath,
                content: data,
                bytesRead: typeof data === "string" ? data.length : undefined,
              };
            }

            throw new Error("No file system implementation available");
          }
          case "write": {
            if (content === undefined || content === null) {
              throw new Error("Content is required for write operations");
            }

            const dataToWrite =
              typeof content === "string"
                ? content
                : JSON.stringify(content, null, 2);

            await ensureDirectoryExists(targetPath);

            if (RNFS) {
              await RNFS.writeFile(targetPath, dataToWrite, "utf8");
            } else if (nodeFsModule) {
              await nodeFsModule.writeFile(targetPath, dataToWrite, "utf8");
            } else {
              throw new Error("No file system implementation available");
            }

            return {
              success: true,
              operation,
              path: targetPath,
              bytesWritten:
                typeof dataToWrite === "string"
                  ? dataToWrite.length
                  : undefined,
            };
          }
          case "list": {
            const stats = await getPathStats(targetPath);
            if (!stats) {
              throw new Error(`Path not found at ${targetPath}`);
            }
            if (!isDirectoryStat(stats)) {
              throw new Error(`Path is not a directory: ${targetPath}`);
            }

            if (RNFS) {
              const entries = await RNFS.readDir(targetPath);
              return {
                success: true,
                operation,
                path: targetPath,
                entries: normalizeDirectoryEntriesFromRN(entries),
              };
            }

            if (nodeFsModule) {
              const entries = await listNodeDirectory(targetPath);
              return {
                success: true,
                operation,
                path: targetPath,
                entries,
              };
            }

            throw new Error("No file system implementation available");
          }
          default:
            throw new Error(`Unsupported file system operation: ${operation}`);
        }
      } catch (error) {
        console.error("File system operation failed:", error);
        return {
          success: false,
          operation,
          path: targetPath,
          error: error.message,
        };
      }
    },
  },
};
