const cache = new Map();

const rateLimiterState = new Map();

const waitFor = (ms) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export function resetCacheAndRateState() {
  cache.clear();
  rateLimiterState.clear();
}

export async function simpleCache(key, fn, ttl = 5 * 60 * 1000) {
  if (typeof fn !== "function") {
    throw new TypeError("simpleCache requires a function to execute");
  }

  const normalizedTtl = Number(ttl);
  if (!Number.isFinite(normalizedTtl)) {
    throw new TypeError("simpleCache requires a finite TTL in milliseconds");
  }

  if (normalizedTtl < 0) {
    throw new RangeError("simpleCache TTL must be non-negative");
  }

  const now = Date.now();
  const existing = cache.get(key);

  if (existing && existing.expiresAt > now) {
    return existing.promise.catch(() => {
      // When the underlying fetch fails, retry the call so each consumer
      // receives its own error instance instead of a shared rejection.
      return simpleCache(key, fn, ttl);
    });
  }

  const promise = (async () => {
    try {
      const value = await fn();
      const resolvedEntry = {
        promise: Promise.resolve(value),
        expiresAt: Date.now() + normalizedTtl,
      };
      cache.set(key, resolvedEntry);
      return value;
    } catch (error) {
      cache.delete(key);
      throw error;
    }
  })();

  cache.set(key, {
    promise,
    expiresAt: now + normalizedTtl,
  });

  return promise;
}

export function rateLimiter(provider, fn, delay = 1000) {
  if (typeof fn !== "function") {
    return Promise.reject(
      new TypeError("rateLimiter requires a function to execute"),
    );
  }

  const normalizedDelay = Number(delay);
  if (!Number.isFinite(normalizedDelay)) {
    return Promise.reject(
      new TypeError("rateLimiter requires a finite delay in milliseconds"),
    );
  }

  if (normalizedDelay < 0) {
    return Promise.reject(
      new RangeError("rateLimiter delay must be non-negative"),
    );
  }

  const safeDelay = normalizedDelay;

  let state = rateLimiterState.get(provider);
  if (!state) {
    state = {
      queue: Promise.resolve(),
      lastInvocationTime: 0,
    };
    rateLimiterState.set(provider, state);
  }

  const run = async () => {
    const now = Date.now();
    const wait = safeDelay - (now - state.lastInvocationTime);
    if (wait > 0) {
      await waitFor(wait);
    }

    state.lastInvocationTime = Date.now();
    return fn();
  };

  const scheduled = state.queue.then(run, () => run());

  state.queue = scheduled
    .then(() => undefined)
    .catch(() => {
      state.queue = Promise.resolve();
    });

  return scheduled;
}
