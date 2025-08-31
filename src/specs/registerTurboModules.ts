// Ensures RN codegen treats these NativeModule specs as "used".
// Safe at runtime: we swallow the error if the native module isn't present.
import { TurboModuleRegistry } from 'react-native';
import type { Spec } from './NativeLLM';

// Mark NativeLLM as used for codegen
(() => {
  try {
    // IMPORTANT: codegen looks specifically for `get<Spec>('Name')` calls.
    TurboModuleRegistry.get<Spec>('NativeLLM');
  } catch {
    // No-op at runtime if Turbo module isn't registered yet.
  }
})();
