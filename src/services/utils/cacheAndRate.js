const cache = new Map();
const lastRequestTimes = new Map();

export async function simpleCache(key, fn, ttl = 5 * 60 * 1000) {
  if (cache.has(key)) {
    const entry = cache.get(key);
    if (Date.now() - entry.timestamp < ttl) {
      return entry.value;
    }
  }
  const value = await fn();
  cache.set(key, { value, timestamp: Date.now() });
  return value;
}

export function rateLimiter(provider, fn, delay = 1000) {
  const now = Date.now();
  const last = lastRequestTimes.get(provider) || 0;
  const remaining = delay - (now - last);
  if (remaining > 0) {
    return new Promise(resolve => {
      setTimeout(async () => {
        lastRequestTimes.set(provider, Date.now());
        resolve(await fn());
      }, remaining);
    });
  }
  lastRequestTimes.set(provider, now);
  return fn();
}
