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
