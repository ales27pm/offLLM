jest.mock("../src/tools/iosTools", () => ({
  getBatteryInfoTool: { name: "get_battery_info", execute: jest.fn() },
  getCurrentLocationTool: { name: "get_current_location", execute: jest.fn() },
  createCalendarEventTool: {
    name: "create_calendar_event",
    execute: jest.fn(),
  },
  showMapTool: { name: "show_map", execute: jest.fn() },
}));

import { toolRegistry } from "../src/core/tools/ToolRegistry";

test("toolRegistry registers built-in tools", () => {
  expect(toolRegistry.getTool("get_battery_info")).toBeDefined();
  expect(toolRegistry.getTool("get_current_location")).toBeDefined();
});

test("unregister removes tools", () => {
  const temp = { name: "temp_tool", execute: jest.fn() };
  toolRegistry.register(temp.name, temp);
  expect(toolRegistry.getTool("temp_tool")).toBeDefined();
  expect(toolRegistry.unregister("temp_tool")).toBe(true);
  expect(toolRegistry.getTool("temp_tool")).toBeUndefined();
  expect(toolRegistry.unregister("temp_tool")).toBe(false);
});

test("register throws for invalid tools", () => {
  expect(() => toolRegistry.register("bad_tool", {})).toThrow(
    "Invalid tool bad_tool: missing execute()",
  );
});
