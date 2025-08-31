import llmService from "../src/services/llmService";
import { ensureModelDownloaded } from "../src/utils/modelDownloader";
import { NativeModules } from "react-native";

jest.mock("../src/utils/modelDownloader", () => ({
  ensureModelDownloaded: jest.fn().mockResolvedValue("/mock/model"),
}));

jest.mock("react-native", () => ({
  NativeModules: {
    LlamaTurboModule: {
      loadModel: jest.fn().mockResolvedValue(true),
      generate: jest
        .fn()
        .mockResolvedValue({ text: "Mock response" }),
    },
  },
  Platform: { OS: "android" },
  TurboModuleRegistry: {
    getOptional: jest.fn().mockReturnValue(null),
  },
}));

jest.mock("react-native-fs", () => ({
  DocumentDirectoryPath: "/mock/path",
  downloadFile: jest.fn().mockReturnValue({ promise: Promise.resolve({ statusCode: 200 }) }),
  exists: jest.fn().mockResolvedValue(true),
}));

describe("LLMService", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    llmService.isReady = false;
  });

  test("loads model and generates response", async () => {
    const res = await llmService.generate("Hello");
    expect(res.text).toBe("Mock response");
    expect(ensureModelDownloaded).toHaveBeenCalled();
    expect(NativeModules.LlamaTurboModule.loadModel).toHaveBeenCalledWith(
      "/mock/model",
      expect.any(Object)
    );
    expect(NativeModules.LlamaTurboModule.generate).toHaveBeenCalled();
  });
});
