import {
  getBatteryInfoTool,
  getCurrentLocationTool,
  createCalendarEventTool,
  showMapTool,
} from "../../tools/iosTools";

const createToolRegistry = () => {
  const tools = new Map();

  return {
    register(name, tool) {
      if (!tool || typeof tool.execute !== "function") {
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
  };
};

export const toolRegistry = createToolRegistry();

// Register native tools
toolRegistry.register("get_battery_info", getBatteryInfoTool);
toolRegistry.register("get_current_location", getCurrentLocationTool);
toolRegistry.register("create_calendar_event", createCalendarEventTool);
toolRegistry.register("show_map", showMapTool);

export default toolRegistry;
