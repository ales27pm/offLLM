import { newDb } from "pg-mem";
import PgVectorStore from "../src/utils/pgVectorStore";

test("PgVectorStore stores and retrieves vectors", async () => {
  const db = newDb();
  const { Pool } = db.adapters.createPg();
  const pool = new Pool();
  const store = new PgVectorStore({ pool, dimensions: 2 });
  // pg-mem lacks pgvector; skip extension by forcing fallback
  store.useArrayFallback = true;
  await store.initialize();
  await store.addVector("hello", [1, 0]);
  await store.addVector("world", [0, 1]);
  const res = await store.searchVectors([1, 0], 1);
  expect(res[0].content).toBe("hello");
});
