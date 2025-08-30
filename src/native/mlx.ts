import { NativeModules } from "react-native";

type MLXNative = {
  loadModel(modelPath: string): Promise<boolean>;
  generate(
    prompt: string,
    maxTokens: number,
    temperature: number
  ): Promise<string>;
};

export const mlx = (NativeModules as { MLXModule: MLXNative }).MLXModule;
