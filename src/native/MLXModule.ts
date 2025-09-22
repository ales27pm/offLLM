// Typed bridge for the native iOS MLXModule
import { NativeModules, Platform } from "react-native";

export type GenerateOptions = {
  topK?: number;
  temperature?: number;
};

type MLXNative = {
  load(modelId?: string): Promise<{ id: string }>;
  generate(prompt: string, options?: GenerateOptions): Promise<string>;
  startStream(prompt: string, options?: GenerateOptions): Promise<void>;
  reset(): void;
  unload(): void;
  stop(): void;
};

const LINK_ERR =
  `MLXModule: native module not linked. ` +
  (Platform.OS === "ios"
    ? "Did you build the iOS app, run pod install, and ensure the Swift/ObjC bridge files are added to the target?"
    : "This module is iOS-only.");

const Native: Partial<MLXNative> = NativeModules.MLXModule ?? {};

if (!Native.load || !Native.generate || !Native.startStream) {
  throw new Error(LINK_ERR);
}

export const MLXModule = Native as MLXNative;
export default MLXModule;
