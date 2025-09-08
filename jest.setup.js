global.__DEV__ = false;
jest.mock("react-native-fs");
jest.mock("react-native-config");
jest.mock("./src/utils/NativeLogger", () => ({}));
