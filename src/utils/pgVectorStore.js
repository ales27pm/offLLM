import { Pool } from "pg";
import { cosineSimilarity } from "./vectorUtils";

function toPgVector(arr) {
  return `[${arr.join(",")}]`;
}

function toPgArray(arr) {
  return `{${arr.join(",")}}`;
}

export class PgVectorStore {
  constructor({
    connectionString = process.env.PGVECTOR_URL || process.env.DATABASE_URL,
    tableName = "agent_memory",
    dimensions = 1536,
    pool,
  } = {}) {
    this.connectionString = connectionString;
    this.tableName = tableName;
    this.dimensions = dimensions;
    this.pool = pool || null;
    this.initialized = false;
    this.useArrayFallback = false;
    this.nodeMap = new Map();
  }

  async _getPool() {
    if (!this.pool) {
      this.pool = new Pool({ connectionString: this.connectionString });
    }
    return this.pool;
  }

  async initialize() {
    if (this.initialized) return;
    const pool = await this._getPool();
    let type = `vector(${this.dimensions})`;
    if (!this.useArrayFallback) {
      try {
        await pool.query("CREATE EXTENSION IF NOT EXISTS vector");
      } catch (e) {
        console.warn(
          "pgvector extension unavailable, falling back to float8[] storage",
          e,
        );
        this.useArrayFallback = true;
      }
    }
    if (this.useArrayFallback) {
      type = "double precision[]";
    }
    await pool.query(
      `CREATE TABLE IF NOT EXISTS ${this.tableName} (\n        id SERIAL PRIMARY KEY,\n        content TEXT NOT NULL,\n        metadata JSONB,\n        embedding ${type}\n      )`,
    );
    this.initialized = true;
  }

  async addVector(content, vector, metadata = {}) {
    await this.initialize();
    const pool = await this._getPool();
    const vec = this.useArrayFallback ? toPgArray(vector) : toPgVector(vector);
    const cast = this.useArrayFallback ? "::double precision[]" : "::vector";
    const res = await pool.query(
      `INSERT INTO ${this.tableName} (content, metadata, embedding) VALUES ($1, $2, $3${cast}) RETURNING id`,
      [content, metadata, vec],
    );
    const id = res.rows[0].id;
    this.nodeMap.set(id, { content, metadata, vector });
    return id;
  }

  async searchVectors(queryVector, limit = 5) {
    await this.initialize();
    const pool = await this._getPool();
    if (!this.useArrayFallback) {
      const q = toPgVector(queryVector);
      const res = await pool.query(
        `SELECT id, content, metadata, embedding <=> $1 AS dist FROM ${this.tableName} ORDER BY embedding <=> $1 LIMIT $2`,
        [q, limit],
      );
      return res.rows.map((r) => ({
        id: r.id,
        content: r.content,
        metadata: r.metadata,
        similarity: 1 - Number(r.dist),
      }));
    }
    // Fallback when pgvector extension is not available
    const res = await pool.query(
      `SELECT id, content, metadata, embedding FROM ${this.tableName}`,
    );
    const scored = res.rows.map((row) => {
      const emb = row.embedding;
      const sim = cosineSimilarity(queryVector, emb);
      this.nodeMap.set(row.id, {
        content: row.content,
        metadata: row.metadata,
        vector: emb,
      });
      return {
        id: row.id,
        content: row.content,
        metadata: row.metadata,
        similarity: sim,
      };
    });
    scored.sort((a, b) => b.similarity - a.similarity);
    return scored.slice(0, limit);
  }
}

export default PgVectorStore;
