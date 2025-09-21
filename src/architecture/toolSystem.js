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

  registerTool(toolName, tool, category) {
    this.tools.set(toolName, tool);
    if (category) {
      if (!this.toolCategories.has(category)) {
        this.toolCategories.set(category, new Set());
      }
      this.toolCategories.get(category).add(toolName);
    }
  }

  async executeTool(toolName, parameters, context) {
    const tool = this.tools.get(toolName);
    if (!tool) {
      throw new Error(`Tool ${toolName} not found`);
    }

    const normalizedParameters = applyParameterDefaults(
      tool,
      parameters && typeof parameters === "object" ? parameters : {},
    );

    try {
      validateParameters(tool, normalizedParameters);

      const executionContext =
        context && typeof context === "object" ? { ...context } : {};
      if (!hasOwn(executionContext, "originalParameters")) {
        executionContext.originalParameters =
          parameters && typeof parameters === "object" ? parameters : {};
      }

      const result = await tool.execute(normalizedParameters, executionContext);

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

  getTool(toolName) {
    return this.tools.get(toolName);
  }

  getAllTools() {
    return Array.from(this.tools.values());
  }

  getExecutionHistory() {
    return this.executionHistory;
  }
}

export const builtInTools = {
  webSearch: {
    name: "webSearch",
    description: "Perform a web search using a specified provider",
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
    name: "fileSystem",
    description: "Perform file system operations (read, write, list)",
    parameters: {
      operation: {
        type: "string",
        required: true,
        description: "Operation to perform (read, write, list)",
        enum: ["read", "write", "list"],
      },
      path: {
        type: "string",
        required: true,
        description: "Path to the file or directory",
      },
      content: {
        type: "string",
        required: false,
        description: "Content to write (for write operations)",
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
