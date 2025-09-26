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

  const now = Date.now();
  const existing = cache.get(key);

  if (existing) {
    if (existing.promise) {
      return existing.promise;
    }

    if (existing.expiresAt > now) {
      return existing.value;
    }

    cache.delete(key);
  }

  const promise = Promise.resolve()
    .then(() => fn())
    .then((value) => {
      cache.set(key, {
        value,
        expiresAt: Date.now() + ttl,
      });
      return value;
    })
    .catch((error) => {
      cache.delete(key);
      throw error;
    });

  cache.set(key, {
    promise,
    expiresAt: now + ttl,
  });

  return promise;
}

export function rateLimiter(provider, fn, delay = 1000) {
  if (typeof fn !== "function") {
    return Promise.reject(
      new TypeError("rateLimiter requires a function to execute"),
    );
  }

  const safeDelay = Math.max(0, delay);

  let state = rateLimiterState.get(provider);
  if (!state) {
    state = {
      queue: Promise.resolve(),
      lastInvocationTime: 0,
      hasRun: false,
    };
    rateLimiterState.set(provider, state);
  }

  const scheduled = state.queue
    .catch(() => undefined)
    .then(async () => {
      const now = Date.now();

      if (state.hasRun) {
        const elapsed = now - state.lastInvocationTime;
        const waitTime = safeDelay - elapsed;
        if (waitTime > 0) {
          await waitFor(waitTime);
        }
      }

      state.lastInvocationTime = Date.now();
      state.hasRun = true;

      return fn();
    });

  state.queue = scheduled.then(
    (value) => value,
    (error) => {
      throw error;
    },
  );

  return scheduled;
}
