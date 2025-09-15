global.__DEV__ = false;
jest.mock("react-native-fs");
jest.mock("react-native", () => ({ Platform: { OS: "ios" } }));
jest.mock("react-native-config");
jest.mock("expo-file-system");
jest.mock("./src/utils/NativeLogger", () => ({}));
