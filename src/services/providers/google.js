import { getApiKeys } from '../utils/apiKeys';
import { googleTimeRange } from '../utils/timeRange';

export async function validateKey() {
  const { googleApiKey, googleSearchEngineId } = await getApiKeys();
  return Boolean(googleApiKey && googleSearchEngineId);
}

export async function search(query, { maxResults, timeRange, safeSearch }) {
  const { googleApiKey, googleSearchEngineId } = await getApiKeys();
  if (!googleApiKey || !googleSearchEngineId) {
    throw new Error('Google API key or search engine ID not configured');
  }
  const dateRestrict = googleTimeRange[timeRange] || '';
  const safe = safeSearch ? 'medium' : 'off';
  const url = `https://www.googleapis.com/customsearch/v1?key=${encodeURIComponent(googleApiKey)}&cx=${encodeURIComponent(googleSearchEngineId)}&q=${encodeURIComponent(query)}&num=${Math.min(maxResults,10)}&safe=${safe}${dateRestrict ? `&dateRestrict=${dateRestrict}` : ''}`;
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
    date: item.pagemap?.metatags?.[0]?.['article:published_time'] || item.pagemap?.metatags?.[0]?.['og:updated_time'] || null
  })) || [];
}
