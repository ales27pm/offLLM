jest.mock("react-native", () => ({ Platform: { OS: "ios" } }), {
  virtual: true,
});
const ReadabilityService =
  require("../src/services/readabilityService").default;

describe("ReadabilityService", () => {
  test("extracts published time from document meta tag", () => {
    const mockDocument = {
      querySelector: (selector) => {
        if (selector === 'meta[property="article:published_time"]') {
          return {
            getAttribute: (attr) =>
              attr === "content" ? "2024-01-02T03:04:05Z" : null,
            textContent: "",
          };
        }
        return null;
      },
    };

    const result = ReadabilityService.extractPublishedTime({}, mockDocument);
    expect(result).toBe("2024-01-02T03:04:05Z");
  });
});
