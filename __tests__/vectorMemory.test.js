import fs from "fs";
import VectorMemory from "../src/memory/VectorMemory";

beforeEach(() => {
  if (fs.existsSync("vector_memory.dat")) fs.unlinkSync("vector_memory.dat");
});

test("VectorMemory recall returns deterministic top-k", async () => {
  const vm = new VectorMemory({ maxMB: 1 });
  await vm.load();
  await vm.remember([
    { vector: [1, 0], content: "hello" },
    { vector: [0, 1], content: "world" },
  ]);
  const res = await vm.recall([1, 0], 1);
  expect(res[0].content).toBe("hello");
});

test("VectorMemory encrypts data at rest", async () => {
  const vm = new VectorMemory({ maxMB: 1 });
  await vm.load();
  await vm.remember([{ vector: [1, 0], content: "secret" }]);
  const raw = fs.readFileSync("vector_memory.dat", "utf8");
  expect(raw.includes("secret")).toBe(false);
});

test("VectorMemory migrations run", async () => {
  const vm = new VectorMemory({ maxMB: 1 });
  await vm.load();
  vm.data.version = 0;
  await vm._save();
  await vm.load();
  expect(vm.data.version).toBe(1);
});

test("VectorMemory enforces size cap", async () => {
  const vm = new VectorMemory({ maxMB: 0.0001 });
  await vm.load();
  for (let i = 0; i < 10; i++) {
    await vm.remember([{ vector: [i, i], content: `m${i}` }]);
  }
  expect(vm.data.items.length).toBeLessThan(10);
});
