jest.mock("react-native-sqlite-storage", () => ({
  openDatabase: jest.fn(),
}));

import { HNSWVectorStore } from "../src/utils/hnswVectorStore";

describe("HNSWVectorStore search", () => {
  test("returns neighbors ordered by similarity", async () => {
    const store = new HNSWVectorStore();
    store.nodeMap = new Map([
      [1, { vector: [1, 0] }],
      [2, { vector: [0.9, 0.1] }],
      [3, { vector: [0, 1] }],
    ]);
    store.index.layers = [
      new Map([
        [1, [2, 3]],
        [2, [1, 3]],
        [3, [1, 2]],
      ]),
    ];

    const results = await store._searchLayer([1, 0], 1, 0, 2);

    expect(results).toEqual([1, 2]);
  });

  test("skips neighbors without cached vectors", async () => {
    const store = new HNSWVectorStore();
    store.nodeMap = new Map([[1, { vector: [1, 0] }]]);
    store.index.layers = [new Map([[1, [2]]])];

    const results = await store._searchLayer([1, 0], 1, 0, 1);

    expect(results).toEqual([1]);
  });
});
