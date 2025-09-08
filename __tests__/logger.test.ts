import RNFS from "react-native-fs";
import Config from "react-native-config";
import { Logger } from "../src/utils/logger";

describe("Logger", () => {
  beforeEach(() => {
    Logger.setFileSink(false);
    Logger.setLevel("debug");
    Logger.clear();
    jest.clearAllMocks();
  });

  it("filters debug when level info", async () => {
    Logger.setLevel("info");
    await Logger.debug("T", "hidden");
    const tail = await Logger.tail();
    expect(tail).toBe("");
  });

  it("maintains ring buffer cap", async () => {
    for (let i = 0; i < 600; i++) {
      await Logger.info("T", `msg${i}`);
    }
    const tail = await Logger.tail(600);
    const lines = tail.split("\n").filter(Boolean);
    expect(lines.length).toBe(500);
    expect(lines[0]).toBe("[T] msg100");
    expect(lines[lines.length - 1]).toBe("[T] msg599");
  });

  it("rotates file when size exceeds 1MB", async () => {
    // enable file sink
    (Config as any).DEBUG_LOGGING = "1";
    Logger.setFileSink(true);
    (RNFS.stat as any).mockResolvedValueOnce({ size: 1024 * 1024 + 1 });
    await Logger.info("T", "rotate");
    // allow async flush
    await new Promise(setImmediate);
    expect(RNFS.moveFile).toHaveBeenCalled();
  });

  it("native forward no-op when bridge missing", async () => {
    await expect(Logger.error("T", "msg")).resolves.toBeUndefined();
  });
});
