import {TurboModuleRegistry} from 'react-native';
import type {Spec} from './NativeLLM';

// IMPORTANT: Codegen looks specifically for this pattern
TurboModuleRegistry.get<Spec>('NativeLLM');

import '../registerTurboModules';
