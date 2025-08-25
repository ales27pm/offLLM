import { searchService } from '../services/webSearchService';

export const webSearchTool = {
    description: 'Search the web for information using multiple providers',
    parameters: {
        query: {
            type: 'string',
            required: true,
            description: 'Search query'
        },
        maxResults: {
            type: 'number',
            required: false,
            description: 'Maximum number of results to return',
            default: 5,
            validate: value => value > 0 && value <= 20
        },
        provider: {
            type: 'string',
            required: false,
            description: 'Search provider to use',
            enum: ['google', 'bing', 'duckduckgo', 'brave'],
            default: 'google'
        },
        timeRange: {
            type: 'string',
            required: false,
            description: 'Time range for results',
            enum: ['day', 'week', 'month', 'year', 'any'],
            default: 'any'
        },
        safeSearch: {
            type: 'boolean',
            required: false,
            description: 'Enable safe search filtering',
            default: true
        },
        extractContent: {
            type: 'boolean',
            required: false,
            description: 'Whether to extract readable content from search results',
            default: true
        }
    },
    execute: async (parameters, context) => {
        const { 
            query, 
            maxResults = 5, 
            provider = 'google', 
            timeRange = 'any',
            safeSearch = true,
            extractContent = true
        } = parameters;
        
        try {
            if (!await validateApiKeys(provider)) {
                throw new Error(`API key not configured for ${provider} search`);
            }
            
            const results = await searchService.performSearchWithContentExtraction(
                provider, query, maxResults, timeRange, safeSearch, extractContent
            );
            
            return {
                results: results.slice(0, maxResults),
                provider,
                query,
                success: true
            };
        } catch (error) {
            console.error('Web search failed:', error);
            return {
                error: error.message,
                provider,
                query,
                success: false
            };
        }
    }
};

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
    return {
        googleApiKey: process.env.GOOGLE_API_KEY,
        googleSearchEngineId: process.env.GOOGLE_SEARCH_ENGINE_ID,
        bingApiKey: process.env.BING_API_KEY,
        braveApiKey: process.env.BRAVE_API_KEY
    };
}
