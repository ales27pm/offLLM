// DuckDuckGo does not require API keys

export async function validateKey() {
  return true;
}

// Parse DuckDuckGo HTML results
function parseResults(html, maxResults) {
  const results = [];
  const resultRegex = /<a class="result__a".*?href="([^"]+)".*?>(.*?)<\/a>.*?<a class="result__snippet".*?>(.*?)<\/a>/gs;
  let match;
  while ((match = resultRegex.exec(html)) !== null && results.length < maxResults) {
    if (match[1].startsWith('//ad.')) continue;
    const url = match[1].startsWith('//') ? 'https:' + match[1] : match[1];
    results.push({
      title: match[2].replace(/<[^>]*>/g, ''),
      url,
      snippet: match[3].replace(/<[^>]*>/g, ''),
      date: null
    });
  }
  return results;
}

export async function search(query, { maxResults, safeSearch }) {
  const safeParam = safeSearch ? 1 : -1;
  const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}&s=${maxResults * 2}&p=${safeParam}`;
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
  });
  if (!response.ok) {
    throw new Error(`DuckDuckGo request failed: ${response.statusText}`);
  }
  const html = await response.text();
  return parseResults(html, maxResults);
}
