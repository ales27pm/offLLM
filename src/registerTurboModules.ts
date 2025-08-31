import {TurboModuleRegistry} from 'react-native';
import type {Spec} from './specs/LLM';

// Mark LLM as used for codegen while tolerating missing native impl.
(() => {
  try {
    // IMPORTANT: codegen looks specifically for `get<Spec>('Name')` calls.
    TurboModuleRegistry.get<Spec>('LLM');
  } catch {}
})();
