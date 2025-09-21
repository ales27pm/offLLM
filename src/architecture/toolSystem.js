import { searchService } from "../services/webSearchService";
import { validate as validateSearchApiKeys } from "../services/utils/apiKeys";
import {
  DEFAULT_MAX_RESULTS,
  DEFAULT_PROVIDER,
  DEFAULT_SAFE_SEARCH,
  DEFAULT_TIME_RANGE,
  MAX_RESULTS_CAP,
  SUPPORTED_PROVIDERS,
  SUPPORTED_TIME_RANGES,
  normalizeMaxResults,
  normalizeProvider,
  normalizeSafeSearch,
  normalizeSearchResults,
  normalizeTimeRange,
} from "../utils/normalizeUtils";
import {
  applyParameterDefaults,
  extractResultAnalytics,
  hasOwn,
  resolveOptionValue,
  validateParameters,
} from "../utils/paramUtils";
import {
  ensureDirectoryExists,
  getNodeFs,
  getPathStats,
  isDirectoryStat,
  listNodeDirectory,
  normalizeDirectoryEntriesFromRN,
  pathExists,
  resolveSafePath,
  getReactNativeFs,
} from "../utils/fsUtils";

const RNFS = getReactNativeFs();

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

    const normalizedParameters = applyParameterDefaults(
      tool,
      parameters && typeof parameters === "object" ? parameters : {},
    );

    try {
      // Validate parameters
      validateParameters(tool, normalizedParameters);

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
        ...(extractResultAnalytics(result) || {}),
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
        const { absolutePath } = resolveSafePath(targetPath);

        switch (operation) {
          case "read": {
            if (!(await pathExists(absolutePath))) {
              throw new Error(`File not found at ${absolutePath}`);
            }

            if (RNFS) {
              const data = await RNFS.readFile(absolutePath, "utf8");
              return {
                success: true,
                operation,
                path: absolutePath,
                content: data,
                bytesRead: typeof data === "string" ? data.length : undefined,
              };
            }

            if (nodeFsModule) {
              const data = await nodeFsModule.readFile(absolutePath, "utf8");
              return {
                success: true,
                operation,
                path: absolutePath,
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
            if (typeof content !== "string") {
              throw new Error(
                "Only string content is supported for write operations",
              );
            }

            await ensureDirectoryExists(absolutePath);

            if (RNFS) {
              await RNFS.writeFile(absolutePath, content, "utf8");
            } else if (nodeFsModule) {
              await nodeFsModule.writeFile(absolutePath, content, "utf8");
            } else {
              throw new Error("No file system implementation available");
            }

            return {
              success: true,
              operation,
              path: absolutePath,
              bytesWritten: content.length,
            };
          }
          case "list": {
            const stats = await getPathStats(absolutePath);
            if (!stats) {
              throw new Error(`Path not found at ${absolutePath}`);
            }
            if (!isDirectoryStat(stats)) {
              throw new Error(`Path is not a directory: ${absolutePath}`);
            }

            if (RNFS) {
              const entries = await RNFS.readDir(absolutePath);
              return {
                success: true,
                operation,
                path: absolutePath,
                entries: normalizeDirectoryEntriesFromRN(entries),
              };
            }

            if (nodeFsModule) {
              const entries = await listNodeDirectory(absolutePath);
              return {
                success: true,
                operation,
                path: absolutePath,
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
