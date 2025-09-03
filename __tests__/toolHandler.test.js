import ToolHandler from "../src/core/tools/ToolHandler";

const handler = new ToolHandler({ getTool: () => null });

test("ToolHandler parses mixed-quote arguments", () => {
  const args = handler._parseArgs(
    "a='one' b=\"two and \\\"quote\\\"\" c='single \\'quote\\'' d=\"path \\\\test\"",
  );
  expect(args).toEqual({
    a: "one",
    b: 'two and "quote"',
    c: "single 'quote'",
    d: "path \\test",
  });
});

test("ToolHandler parses nested JSON and paths", () => {
  const args = handler._parseArgs(
    'config=\'{"a":1,"b":{"c":2}}\' path="C:\\\\Program Files\\\\App"',
  );
  expect(args).toEqual({
    config: { a: 1, b: { c: 2 } },
    path: "C:\\Program Files\\App",
  });
});

test("ToolHandler throws on malformed args", () => {
  expect(() => handler._parseArgs('a=\'one b="two"')).toThrow(
    "Malformed argument string",
  );
  expect(() => handler._parseArgs('json=\'{"a":1')).toThrow(
    "Malformed argument string",
  );
});
