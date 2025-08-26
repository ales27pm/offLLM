import {
  getBatteryInfoTool,
  getCurrentLocationTool,
  createCalendarEventTool,
  showMapTool,
} from "../../tools/iosTools";

export const toolRegistry = {
  tools: new Map(),

  register(name, tool) {
    if (!tool || typeof tool.execute !== "function") {
      throw new Error(`Invalid tool ${name}: missing execute()`);
    }
    this.tools.set(name, tool);
  },

  unregister(name) {
    return this.tools.delete(name);
  },

  getTool(name) {
    return this.tools.get(name);
  },

  getAvailableTools() {
    return Array.from(this.tools.values());
  },
};

// Register native tools
toolRegistry.register("get_battery_info", getBatteryInfoTool);
toolRegistry.register("get_current_location", getCurrentLocationTool);
toolRegistry.register("create_calendar_event", createCalendarEventTool);
toolRegistry.register("show_map", showMapTool);

export default toolRegistry;
