import { NativeModules } from 'react-native';

const CONFIG = NativeModules.Config || {};

export async function getApiKeys() {
  return {
    googleApiKey: CONFIG.GOOGLE_API_KEY,
    googleSearchEngineId: CONFIG.GOOGLE_SEARCH_ENGINE_ID,
    bingApiKey: CONFIG.BING_API_KEY,
    braveApiKey: CONFIG.BRAVE_API_KEY,
  };
}

export async function validateApiKeys(provider) {
  const keys = await getApiKeys();
  switch (provider) {
    case 'google':
      return !!(keys.googleApiKey && keys.googleSearchEngineId);
    case 'bing':
      return !!keys.bingApiKey;
    case 'brave':
      return !!keys.braveApiKey;
    case 'duckduckgo':
      return true;
    default:
      return false;
  }
}

export async function setApiKey(provider, key, additional = {}) {
  switch (provider) {
    case 'google':
      CONFIG.GOOGLE_API_KEY = key;
      if (additional.searchEngineId) {
        CONFIG.GOOGLE_SEARCH_ENGINE_ID = additional.searchEngineId;
      }
      break;
    case 'bing':
      CONFIG.BING_API_KEY = key;
      break;
    case 'brave':
      CONFIG.BRAVE_API_KEY = key;
      break;
    default:
      break;
  }
  return true;
}

export async function getApiKey(provider) {
  const keys = await getApiKeys();
  switch (provider) {
    case 'google':
      return { apiKey: keys.googleApiKey, searchEngineId: keys.googleSearchEngineId };
    case 'bing':
      return { apiKey: keys.bingApiKey };
    case 'brave':
      return { apiKey: keys.braveApiKey };
    default:
      return null;
  }
}
