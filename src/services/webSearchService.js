import ReadabilityService from './readabilityService';

// API Key validation
async function validateApiKeys(provider) {
    const apiKeys = await getApiKeys();
    
    switch (provider) {
        case 'google':
            return !!(apiKeys.googleApiKey && apiKeys.googleSearchEngineId);
        case 'bing':
            return !!apiKeys.bingApiKey;
        case 'brave':
            return !!apiKeys.braveApiKey;
        case 'duckduckgo':
            return true;
        default:
            return false;
    }
}

async function getApiKeys() {
    try {
        return {
            googleApiKey: process.env.GOOGLE_API_KEY,
            googleSearchEngineId: process.env.GOOGLE_SEARCH_ENGINE_ID,
            bingApiKey: process.env.BING_API_KEY,
            braveApiKey: process.env.BRAVE_API_KEY
        };
    } catch (error) {
        console.error('Failed to retrieve API keys:', error);
        return {};
    }
}

async function searchWithGoogle(query, maxResults, timeRange, safeSearch) {
    const apiKey = process.env.GOOGLE_API_KEY;
    const searchEngineId = process.env.GOOGLE_SEARCH_ENGINE_ID;
    
    if (!apiKey || !searchEngineId) {
        throw new Error('Google API key or search engine ID not configured');
    }
    
    const dateRestrict = mapTimeRangeToGoogle(timeRange);
    const safeSearchLevel = safeSearch ? 'medium' : 'off';
    
    const url = `https://www.googleapis.com/customsearch/v1?` +
        `key=${encodeURIComponent(apiKey)}` +
        `&cx=${encodeURIComponent(searchEngineId)}` +
        `&q=${encodeURIComponent(query)}` +
        `&num=${Math.min(maxResults, 10)}` +
        `&safe=${safeSearchLevel}` +
        (dateRestrict ? `&dateRestrict=${dateRestrict}` : '');
    
    try {
        const response = await fetch(url);
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`Google API error: ${errorData.error?.message || response.statusText}`);
        }
        
        const data = await response.json();
        
        return data.items?.map(item => ({
            title: item.title,
            url: item.link,
            snippet: item.snippet,
            date: item.pagemap?.metatags?.[0]?.['article:published_time'] || 
                  item.pagemap?.metatags?.[0]?.['og:updated_time'] || null
        })) || [];
    } catch (error) {
        console.error('Google search failed:', error);
        throw new Error(`Google search failed: ${error.message}`);
    }
}

async function searchWithBing(query, maxResults, timeRange, safeSearch) {
    const apiKey = process.env.BING_API_KEY;
    
    if (!apiKey) {
        throw new Error('Bing API key not configured');
    }
    
    const freshness = mapTimeRangeToBing(timeRange);
    
    const url = `https://api.bing.microsoft.com/v7.0/search?` +
        `q=${encodeURIComponent(query)}` +
        `&count=${maxResults}` +
        `&freshness=${freshness}` +
        `&safeSearch=${safeSearch ? 'Moderate' : 'Off'}`;
    
    try {
        const response = await fetch(url, {
            headers: {
                'Ocp-Apim-Subscription-Key': apiKey
            }
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Bing API error: ${response.statusText} - ${errorText}`);
        }
        
        const data = await response.json();
        
        return data.webPages?.value?.map(item => ({
            title: item.name,
            url: item.url,
            snippet: item.snippet,
            date: item.dateLastCrawled || null
        })) || [];
    } catch (error) {
        console.error('Bing search failed:', error);
        throw new Error(`Bing search failed: ${error.message}`);
    }
}

async function searchWithDuckDuckGo(query, maxResults, timeRange, safeSearch) {
    const safeSearchParam = safeSearch ? 1 : -1;
    
    const url = `https://html.duckduckgo.com/html/?` +
        `q=${encodeURIComponent(query)}` +
        `&s=${maxResults * 2}` +
        `&p=${safeSearchParam}`;
    
    try {
        const response = await fetch(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        });
        
        if (!response.ok) {
            throw new Error(`DuckDuckGo request failed: ${response.statusText}`);
        }
        
        const html = await response.text();
        
        return parseDuckDuckGoResults(html, maxResults);
    } catch (error) {
        console.error('DuckDuckGo search failed:', error);
        throw new Error(`DuckDuckGo search failed: ${error.message}`);
    }
}

function parseDuckDuckGoResults(html, maxResults) {
    const results = [];
    
    const resultRegex = /<a class="result__a".*?href="([^"]+)".*?>(.*?)<\/a>.*?<a class="result__snippet".*?>(.*?)<\/a>/gs;
    
    let match;
    while ((match = resultRegex.exec(html)) !== null && results.length < maxResults) {
        if (match[1].startsWith('//ad.')) continue;
        
        const url = match[1].startsWith('//') ? 'https:' + match[1] : match[1];
        
        results.push({
            title: match[2].replace(/<[^>]*>/g, ''),
            url: url,
            snippet: match[3].replace(/<[^>]*>/g, ''),
            date: null
        });
    }
    
    return results;
}

async function searchWithBrave(query, maxResults, timeRange, safeSearch) {
    const apiKey = process.env.BRAVE_API_KEY;
    
    if (!apiKey) {
        throw new Error('Brave API key not configured');
    }
    
    const freshness = mapTimeRangeToBrave(timeRange);
    
    const url = `https://api.search.brave.com/res/v1/web/search?` +
        `q=${encodeURIComponent(query)}` +
        `&count=${maxResults}` +
        `&freshness=${freshness}` +
        `&safesearch=${safeSearch ? 'moderate' : 'off'}`;
    
    try {
        const response = await fetch(url, {
            headers: {
                'Accept': 'application/json',
                'Accept-Encoding': 'gzip',
                'X-Subscription-Token': apiKey
            }
        });
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`Brave API error: ${errorData.message || response.statusText}`);
        }
        
        const data = await response.json();
        
        return data.web?.results?.map(item => ({
            title: item.title,
            url: item.url,
            snippet: item.description,
            date: item.age || null
        })) || [];
    } catch (error) {
        console.error('Brave search failed:', error);
        throw new Error(`Brave search failed: ${error.message}`);
    }
}

function mapTimeRangeToGoogle(timeRange) {
    switch (timeRange) {
        case 'day': return 'd1';
        case 'week': return 'w1';
        case 'month': return 'm1';
        case 'year': return 'y1';
        default: return '';
    }
}

function mapTimeRangeToBing(timeRange) {
    switch (timeRange) {
        case 'day': return 'Day';
        case 'week': return 'Week';
        case 'month': return 'Month';
        default: return '';
    }
}

function mapTimeRangeToBrave(timeRange) {
    switch (timeRange) {
        case 'day': return 'pd';
        case 'week': return 'pw';
        case 'month': return 'pm';
        case 'year': return 'py';
        default: return '';
    }
}

const searchCache = new Map();
const RATE_LIMIT_DELAY = 1000;

export class SearchService {
    constructor() {
        this.lastRequestTimes = new Map();
    }
    
    async performSearch(provider, query, maxResults, timeRange, safeSearch) {
        const cacheKey = `${provider}:${query}:${maxResults}:${timeRange}:${safeSearch}`;
        
        if (searchCache.has(cacheKey)) {
            const cached = searchCache.get(cacheKey);
            if (Date.now() - cached.timestamp < 5 * 60 * 1000) {
                return cached.results;
            }
        }
        
        const lastRequestTime = this.lastRequestTimes.get(provider) || 0;
        const timeSinceLastRequest = Date.now() - lastRequestTime;
        
        if (timeSinceLastRequest < RATE_LIMIT_DELAY) {
            await new Promise(resolve => 
                setTimeout(resolve, RATE_LIMIT_DELAY - timeSinceLastRequest)
            );
        }
        
        let results;
        switch (provider) {
            case 'google':
                results = await searchWithGoogle(query, maxResults, timeRange, safeSearch);
                break;
            case 'bing':
                results = await searchWithBing(query, maxResults, timeRange, safeSearch);
                break;
            case 'duckduckgo':
                results = await searchWithDuckDuckGo(query, maxResults, timeRange, safeSearch);
                break;
            case 'brave':
                results = await searchWithBrave(query, maxResults, timeRange, safeSearch);
                break;
            default:
                throw new Error(`Unknown search provider: ${provider}`);
        }
        
        this.lastRequestTimes.set(provider, Date.now());
        
        searchCache.set(cacheKey, {
            results,
            timestamp: Date.now()
        });
        
        this.cleanupCache();
        
        return results;
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
    
    async performSearchWithContentExtraction(provider, query, maxResults, timeRange, safeSearch, extractContent = true) {
        const searchResults = await this.performSearch(provider, query, maxResults, timeRange, safeSearch);
        
        if (!extractContent) {
            return searchResults;
        }
        
        const enhancedResults = [];
        for (const result of searchResults) {
            try {
                const content = await ReadabilityService.extractFromUrl(result.url);
                enhancedResults.push({
                    ...result,
                    extractedContent: content,
                    contentExtracted: true
                });
            } catch (error) {
                console.error(`Failed to extract content from ${result.url}:`, error);
                enhancedResults.push({
                    ...result,
                    extractedContent: null,
                    contentExtracted: false,
                    extractionError: error.message
                });
            }
        }
        
        return enhancedResults;
    }
}

export const searchService = new SearchService();

export class ApiKeyManager {
    static async setApiKey(provider, key, additionalData = null) {
        try {
            switch (provider) {
                case 'google':
                    process.env.GOOGLE_API_KEY = key;
                    if (additionalData && additionalData.searchEngineId) {
                        process.env.GOOGLE_SEARCH_ENGINE_ID = additionalData.searchEngineId;
                    }
                    break;
                case 'bing':
                    process.env.BING_API_KEY = key;
                    break;
                case 'brave':
                    process.env.BRAVE_API_KEY = key;
                    break;
                default:
                    throw new Error(`Unknown provider: ${provider}`);
            }
            
            return true;
        } catch (error) {
            console.error('Failed to set API key:', error);
            return false;
        }
    }
    
    static async getApiKey(provider) {
        switch (provider) {
            case 'google':
                return {
                    apiKey: process.env.GOOGLE_API_KEY,
                    searchEngineId: process.env.GOOGLE_SEARCH_ENGINE_ID
                };
            case 'bing':
                return { apiKey: process.env.BING_API_KEY };
            case 'brave':
                return { apiKey: process.env.BRAVE_API_KEY };
            default:
                return null;
        }
    }
    
    static async hasApiKey(provider) {
        const keys = await this.getApiKey(provider);
        
        if (provider === 'google') {
            return !!(keys.apiKey && keys.searchEngineId);
        }
        
        return !!keys.apiKey;
    }
}
