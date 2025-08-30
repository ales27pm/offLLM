import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

export interface GenerateOptions {
  maxTokens?: number;
  temperature?: number;
  topK?: number;
  topP?: number;
  stop?: string[] | null;
}

export interface LoadOptions {
  quantization?: string | null; // e.g., "Q4_0", "Q8_0"
  contextLength?: number | null;
}

export interface PerfMetrics {
  memoryUsage?: number; // 0..1
  cpuUsage?: number; // 0..1
}

export interface Spec extends TurboModule {
  loadModel(path: string, options?: LoadOptions | null): Promise<boolean>;
  unloadModel(): Promise<boolean>;
  generate(prompt: string, options?: GenerateOptions | null): Promise<string>;
  embed(text: string): Promise<number[]>;
  getPerformanceMetrics(): Promise<PerfMetrics>;
  getKVCacheSize(): Promise<number>;
  getKVCacheMaxSize(): Promise<number>;
  clearKVCache(): Promise<void>;
  addMessageBoundary(): Promise<void>;
  adjustPerformanceMode(mode: string): Promise<boolean>;
}

export default TurboModuleRegistry.getOptional<Spec>("LLM");
