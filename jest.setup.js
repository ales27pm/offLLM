global.__DEV__ = false;
jest.mock("react-native-fs");
jest.mock("react-native", () => ({
  NativeModules: { DeviceInfo: {} },
  Platform: { OS: "ios" },
  TurboModuleRegistry: {
    getOptional: jest.fn().mockReturnValue(null),
  },
}));
jest.mock("react-native-config");
jest.mock("expo-file-system");
jest.mock("./src/utils/NativeLogger", () => ({}));
