import { getApiKeys } from '../utils/apiKeys';
import { bingTimeRange } from '../utils/timeRange';

export async function validateKey() {
  const { bingApiKey } = await getApiKeys();
  return Boolean(bingApiKey);
}

export async function search(query, { maxResults, timeRange, safeSearch }) {
  const { bingApiKey } = await getApiKeys();
  if (!bingApiKey) {
    throw new Error('Bing API key not configured');
  }
  const freshness = bingTimeRange[timeRange] || '';
  const url = `https://api.bing.microsoft.com/v7.0/search?q=${encodeURIComponent(query)}&count=${maxResults}&freshness=${freshness}&safeSearch=${safeSearch ? 'Moderate' : 'Off'}`;
  const response = await fetch(url, {
    headers: { 'Ocp-Apim-Subscription-Key': bingApiKey }
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
}
