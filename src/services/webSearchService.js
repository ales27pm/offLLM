import ReadabilityService from './readabilityService';
import * as google from './providers/google';
import * as bing from './providers/bing';
import * as duckduckgo from './providers/duckduckgo';
import * as brave from './providers/brave';
import { validateApiKeys, setApiKey, getApiKey } from './utils/apiKeys';

const PROVIDERS = { google, bing, duckduckgo, brave };
const searchCache = new Map();
const RATE_LIMIT_DELAY = 1000;

export class SearchService {
  constructor() {
    this.lastRequestTimes = new Map();
  }

  async performSearch(providerName, query, maxResults, timeRange, safeSearch) {
    const provider = PROVIDERS[providerName];
    if (!provider) throw new Error(`Unknown search provider: ${providerName}`);
    if (!(await provider.validateKey())) {
      throw new Error(`API key not configured for ${providerName} search`);
    }

    const cacheKey = `${providerName}:${query}:${maxResults}:${timeRange}:${safeSearch}`;
    const cached = searchCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < 5 * 60 * 1000) {
      return cached.results;
    }

    const last = this.lastRequestTimes.get(providerName) || 0;
    const wait = RATE_LIMIT_DELAY - (Date.now() - last);
    if (wait > 0) {
      await new Promise(resolve => setTimeout(resolve, wait));
    }

    const results = await provider.search(query, { maxResults, timeRange, safeSearch });
    this.lastRequestTimes.set(providerName, Date.now());
    searchCache.set(cacheKey, { results, timestamp: Date.now() });
    this.cleanupCache();
    return results;
  }

  async performSearchWithContentExtraction(provider, query, maxResults, timeRange, safeSearch, extractContent = true) {
    const results = await this.performSearch(provider, query, maxResults, timeRange, safeSearch);
    if (!extractContent) return results;
    const enhanced = [];
    for (const result of results) {
      try {
        const content = await ReadabilityService.extractFromUrl(result.url);
        enhanced.push({ ...result, extractedContent: content, contentExtracted: true });
      } catch (error) {
        console.error(`Failed to extract content from ${result.url}:`, error);
        enhanced.push({ ...result, extractedContent: null, contentExtracted: false, extractionError: error.message });
      }
    }
    return enhanced;
  }

  cleanupCache() {
    const now = Date.now();
    for (const [key, value] of searchCache.entries()) {
      if (now - value.timestamp > 30 * 60 * 1000) {
        searchCache.delete(key);
      }
    }
  }

  clearCache() {
    searchCache.clear();
  }
}

export class ApiKeyManager {
  static async setApiKey(provider, key, additionalData = null) {
    return setApiKey(provider, key, additionalData || {});
  }

  static async getApiKey(provider) {
    return getApiKey(provider);
  }

  static async hasApiKey(provider) {
    return validateApiKeys(provider);
  }
}

export const searchService = new SearchService();
