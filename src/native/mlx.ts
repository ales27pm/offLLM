import { NativeModules } from "react-native";

type MLXNative = {
  loadModel(_modelPath: string): Promise<boolean>;
  generate(
    _prompt: string,
    _maxTokens: number,
    _temperature: number
  ): Promise<string>;
};

export const mlx = (NativeModules as { MLXModule: MLXNative }).MLXModule;
