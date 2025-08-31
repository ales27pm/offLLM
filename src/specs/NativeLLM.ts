import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';

export interface GenerateOptions { maxTokens?: number; temperature?: number; topK?: number; topP?: number; stop?: string[] | null; }
export interface LoadOptions { quantization?: string | null; contextLength?: number | null; }
export interface PerfMetrics { memoryUsage?: number; cpuUsage?: number; }

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

// Probe for codegen so the spec is marked as used.
try {
  // IMPORTANT: codegen looks specifically for `get<Spec>('Name')` calls.
  TurboModuleRegistry.get<Spec>('LLM');
} catch {
  // Ignore missing native module during runtime.
}

// Expose the TurboModule; returns `null` when the native implementation is missing.
export default TurboModuleRegistry.getOptional<Spec>('LLM');

