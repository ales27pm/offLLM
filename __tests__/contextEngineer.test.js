import { ContextEngineer } from "../src/services/contextEngineer";

describe("ContextEngineer sparse retrieval", () => {
  const createEngineer = ({ vectorStore, llmService, contextEvaluator } = {}) =>
    new ContextEngineer({
      vectorStore,
      llmService: llmService ?? {
        embed: jest.fn(),
        generate: jest.fn(),
      },
      contextEvaluator: contextEvaluator ?? {
        evaluateContext: jest.fn(),
        prioritizeContext: jest.fn(),
      },
    });

  test("uses sparse retrieval when available", async () => {
    const sparse = jest.fn().mockResolvedValue([{ id: "a" }]);
    const store = {
      searchVectorsSparse: sparse,
      searchVectors: jest.fn(),
    };
    const engineer = createEngineer({ vectorStore: store });

    const result = await engineer._retrieveRelevantChunksSparse([0.1, 0.2], 3);

    expect(sparse).toHaveBeenCalledWith([0.1, 0.2], 3, {
      useHierarchical: true,
      numClusters: 3,
    });
    expect(result).toEqual([{ id: "a" }]);
    expect(store.searchVectors).not.toHaveBeenCalled();
  });

  test("falls back to dense search when sparse retrieval fails", async () => {
    const sparse = jest.fn().mockRejectedValue(new Error("fail"));
    const dense = jest.fn().mockResolvedValue([{ id: "fallback" }]);
    const store = {
      searchVectorsSparse: sparse,
      searchVectors: dense,
    };
    const engineer = createEngineer({ vectorStore: store });
    const consoleError = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    const result = await engineer._retrieveRelevantChunksSparse([0.4], 2);

    expect(dense).toHaveBeenCalledWith([0.4], 2);
    expect(result).toEqual([{ id: "fallback" }]);

    consoleError.mockRestore();
  });

  test("returns empty results when no vector store is configured", async () => {
    const engineer = createEngineer({ vectorStore: null });

    await expect(
      engineer._retrieveRelevantChunksSparse([0.5], 1),
    ).resolves.toEqual([]);
  });
});
