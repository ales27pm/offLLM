// Typed bridge for the native iOS MLXModule
import { NativeModules, Platform } from "react-native";

type MLXNative = {
  load(_modelId?: string): Promise<boolean>;
  isLoaded(): Promise<boolean>;
  generate(_prompt: string): Promise<string>;
  reset(): void;
  unload(): void;
};

const LINK_ERR =
  `MLXModule: native module not linked. ` +
  (Platform.OS === "ios"
    ? "Did you build the iOS app, run pod install, and ensure the Swift/ObjC bridge files are in the Xcode target?"
    : "This module is iOS-only.");

const Native: Partial<MLXNative> = NativeModules.MLXModule;

if (!Native || !Native.load || !Native.generate) {
  throw new Error(LINK_ERR);
}

export const MLXModule = Native as MLXNative;
export default MLXModule;
