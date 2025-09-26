const ORIGINAL_TIMEOUT = 5000;

describe("cacheAndRate utilities", () => {
  beforeEach(() => {
    jest.resetModules();
    jest.useFakeTimers({ doNotFake: ["nextTick"] });
    jest.setTimeout(250);
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.setTimeout(ORIGINAL_TIMEOUT);
    jest.restoreAllMocks();
  });

  const loadModule = () => require("../src/services/utils/cacheAndRate");

  it("deduplicates concurrent cache calls and respects TTL", async () => {
    jest.setSystemTime(new Date("2024-01-01T00:00:00.000Z"));
    const { simpleCache, resetCacheAndRateState } = loadModule();

    const fn = jest
      .fn()
      .mockResolvedValueOnce("first")
      .mockResolvedValueOnce("second");

    const first = simpleCache("key", fn, 1000);
    const second = simpleCache("key", fn, 1000);

    await expect(Promise.all([first, second])).resolves.toEqual([
      "first",
      "first",
    ]);
    expect(fn).toHaveBeenCalledTimes(1);

    jest.advanceTimersByTime(500);
    jest.setSystemTime(new Date("2024-01-01T00:00:00.500Z"));

    await expect(simpleCache("key", fn, 1000)).resolves.toBe("first");
    expect(fn).toHaveBeenCalledTimes(1);

    jest.advanceTimersByTime(600);
    jest.setSystemTime(new Date("2024-01-01T00:00:01.100Z"));

    await expect(simpleCache("key", fn, 1000)).resolves.toBe("second");
    expect(fn).toHaveBeenCalledTimes(2);

    resetCacheAndRateState();
  });

  it("does not cache errors", async () => {
    jest.setSystemTime(new Date("2024-01-01T00:00:00.000Z"));
    const { simpleCache, resetCacheAndRateState } = loadModule();

    const error = new Error("boom");
    const fn = jest
      .fn()
      .mockRejectedValueOnce(error)
      .mockResolvedValueOnce("recovered");

    await expect(simpleCache("key", fn, 1000)).rejects.toBe(error);
    await expect(simpleCache("key", fn, 1000)).resolves.toBe("recovered");
    expect(fn).toHaveBeenCalledTimes(2);

    resetCacheAndRateState();
  });

  it("propagates errors from delayed rate-limited executions and continues queueing", async () => {
    jest.setSystemTime(new Date("2024-01-01T00:00:00.000Z"));
    const { rateLimiter, resetCacheAndRateState } = loadModule();

    const successFn = jest.fn().mockResolvedValue("ok");
    const error = new Error("boom");
    const failingFn = jest.fn().mockRejectedValue(error);

    await rateLimiter("provider", successFn, 50);

    const pendingPromise = rateLimiter("provider", failingFn, 50);
    const expectation = expect(pendingPromise).rejects.toMatchObject({
      message: "boom",
    });

    await jest.advanceTimersByTimeAsync(50);
    await expectation;

    const afterError = rateLimiter("provider", successFn, 50);
    await jest.advanceTimersByTimeAsync(50);
    await expect(afterError).resolves.toBe("ok");

    expect(failingFn).toHaveBeenCalledTimes(1);
    expect(successFn).toHaveBeenCalledTimes(2);

    resetCacheAndRateState();
  });

  it("serialises bursts of rate limited calls", async () => {
    jest.setSystemTime(new Date("2024-01-01T00:00:00.000Z"));
    const { rateLimiter, resetCacheAndRateState } = loadModule();

    const invocationTimes = [];
    const fn = jest.fn().mockImplementation(() => {
      invocationTimes.push(Date.now());
      return Promise.resolve(invocationTimes.length);
    });

    const p1 = rateLimiter("provider", fn, 100);
    const p2 = rateLimiter("provider", fn, 100);
    const p3 = rateLimiter("provider", fn, 100);

    await jest.advanceTimersByTimeAsync(300);

    await expect(Promise.all([p1, p2, p3])).resolves.toEqual([1, 2, 3]);
    const deltas = invocationTimes.map((time, index) =>
      index === 0 ? 0 : time - invocationTimes[0],
    );
    expect(deltas).toEqual([0, 100, 200]);
    expect(fn).toHaveBeenCalledTimes(3);

    resetCacheAndRateState();
  });
});
