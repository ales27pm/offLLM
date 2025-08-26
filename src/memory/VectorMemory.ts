import fs from 'fs';
import path from 'path';
import { randomBytes, createCipheriv, createDecipheriv } from 'crypto';
import { cosineSimilarity } from '../utils/vectorUtils';
import { getEnv } from '../config';
import { runMigrations, CURRENT_VERSION } from './migrations';

export interface MemoryItem {
  id: string;
  vector: number[];
  content: string;
  metadata?: Record<string, any>;
  conversationId?: string;
  timestamp: number;
}

interface StoredData {
  version: number;
  items: MemoryItem[];
}

function getKey() {
  const source = getEnv('MEMORY_ENCRYPTION_KEY_SOURCE') || 'env';
  if (source === 'env') {
    return (getEnv('MEMORY_ENCRYPTION_KEY') || '').padEnd(32, '0').slice(0, 32);
  }
  // fallback fixed key for tests
  return 'default_memory_encryption_key_32';
}

export default class VectorMemory {
  filePath: string;
  maxBytes: number;
  key: Buffer;
  data: StoredData;

  constructor({
    filePath = path.join(process.cwd(), 'vector_memory.dat'),
    maxMB = Number(getEnv('MEMORY_MAX_MB') || '10'),
  } = {}) {
    this.filePath = filePath;
    this.maxBytes = maxMB * 1024 * 1024;
    this.key = Buffer.from(getKey());
    this.data = { version: CURRENT_VERSION, items: [] };
  }

  async load() {
    if (fs.existsSync(this.filePath)) {
      const encrypted = fs.readFileSync(this.filePath);
      const json = this._decrypt(encrypted);
      this.data = JSON.parse(json);
      await runMigrations(this.data);
    } else {
      await this._save();
    }
  }

  async remember(items: MemoryItem[]) {
    for (const item of items) {
      this.data.items.push({ ...item, id: item.id || randomBytes(8).toString('hex'), timestamp: Date.now() });
    }
    this._enforceLimits();
    await this._save();
  }

  async recall(queryVector: number[], k = 5, filters?: { conversationId?: string }) {
    const items = this.data.items.filter((i) => {
      if (filters?.conversationId && i.conversationId !== filters.conversationId) return false;
      return true;
    });
    const scored = items.map((i) => ({
      item: i,
      score: cosineSimilarity(queryVector, i.vector),
    }));
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, k).map((s) => ({ ...s.item, score: s.score }));
  }

  async wipe(scope?: { conversationId?: string }) {
    if (!scope) {
      this.data.items = [];
    } else if (scope.conversationId) {
      this.data.items = this.data.items.filter((i) => i.conversationId !== scope.conversationId);
    }
    await this._save();
  }

  export() {
    const encrypted = fs.readFileSync(this.filePath);
    return encrypted.toString('base64');
  }

  async import(data: string) {
    const buf = Buffer.from(data, 'base64');
    fs.writeFileSync(this.filePath, buf);
    await this.load();
  }

  _enforceLimits() {
    const serialized = Buffer.from(JSON.stringify(this.data));
    if (serialized.length <= this.maxBytes) return;
    // simple LRU by timestamp
    this.data.items.sort((a, b) => a.timestamp - b.timestamp);
    while (Buffer.from(JSON.stringify(this.data)).length > this.maxBytes) {
      this.data.items.shift();
    }
  }

  _encrypt(plaintext: string) {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const enc = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return Buffer.concat([iv, tag, enc]);
  }

  _decrypt(buffer: Buffer) {
    const iv = buffer.subarray(0, 12);
    const tag = buffer.subarray(12, 28);
    const enc = buffer.subarray(28);
    const decipher = createDecipheriv('aes-256-gcm', this.key, iv);
    decipher.setAuthTag(tag);
    const dec = Buffer.concat([decipher.update(enc), decipher.final()]);
    return dec.toString('utf8');
  }

  async _save() {
    const json = JSON.stringify(this.data);
    const encrypted = this._encrypt(json);
    fs.writeFileSync(this.filePath, encrypted);
  }
}

