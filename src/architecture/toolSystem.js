import { searchService } from "../services/webSearchService";
import { validate as validateSearchApiKeys } from "../services/utils/apiKeys";
import {
  DEFAULT_MAX_RESULTS,
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
  validateParameters,
} from "../utils/paramUtils";

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
    execute: async (parameters, _context) => {
      const { query, maxResults, provider, timeRange, safeSearch } = parameters;
      const normalizedMaxResults = normalizeMaxResults(maxResults);
      const normalizedProvider = normalizeProvider(provider);
      const normalizedTimeRange = normalizeTimeRange(timeRange);
      const normalizedSafeSearch = normalizeSafeSearch(safeSearch);

      try {
        await validateSearchApiKeys();
        const results = await searchService.search({
          query,
          maxResults: normalizedMaxResults,
          provider: normalizedProvider,
          timeRange: normalizedTimeRange,
          safeSearch: normalizedSafeSearch,
        });

        return {
          results: normalizeSearchResults(results),
          success: true,
        };
      } catch (error) {
        return {
          error: error.message,
          success: false,
        };
      }
    },
  },
};
