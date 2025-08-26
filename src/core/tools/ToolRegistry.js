import * as iosTools from '../../tools/iosTools';
import * as androidTools from '../../tools/androidTools';
import { Platform } from 'react-native';

const createToolRegistry = () => {
  const tools = new Map();

  return {
    register(name, tool) {
      if (!tool || typeof tool.execute !== 'function') {
        throw new Error(`Invalid tool ${name}: missing execute()`);
      }
      tools.set(name, tool);
    },
    unregister(name) {
      return tools.delete(name);
    },
    getTool(name) {
      return tools.get(name);
    },
    getAvailableTools() {
      return Array.from(tools.values());
    },
    autoRegister(module) {
      Object.values(module).forEach((tool) => {
        if (tool && typeof tool.execute === 'function') {
          this.register(tool.name, tool);
        }
      });
    },
  };
};

export const toolRegistry = createToolRegistry();

const moduleToUse = Platform.OS === 'android' ? androidTools : iosTools;
toolRegistry.autoRegister(moduleToUse);

export default toolRegistry;
