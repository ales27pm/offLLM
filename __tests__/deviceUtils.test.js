describe("device hardware detection", () => {
  const originalNodeEnv = process.env.NODE_ENV;
  const originalEncryptionKey = process.env.MEMORY_ENCRYPTION_KEY;

  afterEach(() => {
    process.env.NODE_ENV = originalNodeEnv;
    if (originalEncryptionKey === undefined) {
      delete process.env.MEMORY_ENCRYPTION_KEY;
    } else {
      process.env.MEMORY_ENCRYPTION_KEY = originalEncryptionKey;
    }
    jest.resetModules();
  });

  test("uses node hardware probes when native metrics are unavailable", () => {
    jest.resetModules();
    process.env.NODE_ENV = "production";
    if (!process.env.MEMORY_ENCRYPTION_KEY) {
      process.env.MEMORY_ENCRYPTION_KEY = "test-key-123456789012";
    }

    const { getDeviceProfile } = require("../src/utils/deviceUtils");
    const profile = getDeviceProfile();

    expect(profile.processorCores).toBeGreaterThan(0);
    expect(profile.totalMemory).toBeGreaterThan(0);
    expect(profile.detectionMethod).not.toContain("fallback");
  });
});
