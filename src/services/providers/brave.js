import { getApiKeys } from '../utils/apiKeys';
import { braveTimeRange } from '../utils/timeRange';

export async function validateKey() {
  const { braveApiKey } = await getApiKeys();
  return Boolean(braveApiKey);
}

export async function search(query, { maxResults, timeRange, safeSearch }) {
  const { braveApiKey } = await getApiKeys();
  if (!braveApiKey) {
    throw new Error('Brave API key not configured');
  }
  const freshness = braveTimeRange[timeRange] || '';
  const url = `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(query)}&count=${maxResults}&freshness=${freshness}&safesearch=${safeSearch ? 'moderate' : 'off'}`;
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'Accept-Encoding': 'gzip',
      'X-Subscription-Token': braveApiKey,
    },
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
    date: item.age || null,
  })) || [];
}
