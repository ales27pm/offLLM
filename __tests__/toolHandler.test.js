import ToolHandler from "../src/core/tools/ToolHandler";

const handler = new ToolHandler({ getTool: () => null });

test("ToolHandler parses mixed-quote arguments", () => {
  const args = handler._parseArgs(
    "a='one' b=\"two and \\\"quote\\\"\" c='single \\'quote\\'' d=\"path \\\\test\""
  );
  expect(args).toEqual({
    a: "one",
    b: 'two and "quote"',
    c: "single 'quote'",
    d: "path \\test",
  });
});

test("ToolHandler throws on malformed args", () => {
  expect(() => handler._parseArgs('a=\'one b="two"')).toThrow(
    "Malformed argument string"
  );
});
