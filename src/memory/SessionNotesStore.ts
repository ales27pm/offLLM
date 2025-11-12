import path from "path";
import { randomBytes } from "crypto";
import FileStorage from "../services/fileStorage";
import EncryptionService from "../services/encryption";
import { getEnv } from "../config";

export interface SessionNoteRecord {
  id: string;
  key: string;
  message: string;
  suggestion?: string;
  tags?: string[];
  occurrences: number;
  firstSeen: number;
  lastSeen: number;
  lastContext?: Record<string, unknown>;
}

interface StoredNotes {
  version: number;
  notes: SessionNoteRecord[];
}

const DEFAULT_MAX_NOTES = 50;
export const SESSION_NOTES_CURRENT_VERSION = 1;

let cachedEphemeralKey: string | null = null;
let hasWarnedMissingKey = false;

function normalizeKeyLength(key: string) {
  return key.padEnd(32, "0").slice(0, 32);
}

function resolveEncryptionKey() {
  const envKey =
    getEnv("SESSION_NOTES_ENCRYPTION_KEY") || getEnv("MEMORY_ENCRYPTION_KEY");

  if (!envKey) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(
        "[SessionNotes] SESSION_NOTES_ENCRYPTION_KEY (or MEMORY_ENCRYPTION_KEY) is required in production.",
      );
    }

    const shouldWarn = process.env.NODE_ENV !== "test" && !hasWarnedMissingKey;
    if (shouldWarn) {
      console.warn(
        "[SessionNotes] Missing encryption key; falling back to ephemeral development key.",
      );
      hasWarnedMissingKey = true;
    }

    if (!cachedEphemeralKey) {
      cachedEphemeralKey = randomBytes(16).toString("hex");
    }

    return normalizeKeyLength(cachedEphemeralKey);
  }

  hasWarnedMissingKey = false;
  cachedEphemeralKey = null;
  return normalizeKeyLength(envKey);
}

export interface SessionNoteInput {
  key: string;
  message: string;
  suggestion?: string;
  tags?: string[];
  context?: Record<string, unknown>;
  timestamp?: number;
}

export interface GetNotesOptions {
  limit?: number;
  minOccurrences?: number;
}

export default class SessionNotesStore {
  private storage: FileStorage;
  private crypto: EncryptionService;
  private maxNotes: number;
  private data: StoredNotes;
  private loaded: boolean;

  constructor({
    filePath = path.join(process.cwd(), "session_notes.dat"),
    maxNotes = DEFAULT_MAX_NOTES,
  }: {
    filePath?: string;
    maxNotes?: number;
  } = {}) {
    this.storage = new FileStorage(filePath);
    this.crypto = new EncryptionService(
      Buffer.from(resolveEncryptionKey(), "utf8"),
    );
    this.maxNotes = maxNotes;
    this.data = { version: SESSION_NOTES_CURRENT_VERSION, notes: [] };
    this.loaded = false;
  }

  async load() {
    if (this.loaded) {
      return;
    }

    const raw = await this.storage.loadRaw();
    if (raw) {
      try {
        const json = this.crypto.decrypt(raw);
        const parsed = JSON.parse(json) as StoredNotes;
        this.data = this.#normalise(parsed);
      } catch (error) {
        console.warn(
          "[SessionNotes] Failed to load existing notes, resetting store.",
          error,
        );
        this.data = { version: SESSION_NOTES_CURRENT_VERSION, notes: [] };
        await this.#save();
      }
    } else {
      await this.#save();
    }

    this.loaded = true;
  }

  async getTopNotes({ limit = 3, minOccurrences = 1 }: GetNotesOptions = {}) {
    await this.load();
    const filtered = this.data.notes.filter(
      (note) => note.occurrences >= minOccurrences,
    );

    const sorted = [...filtered].sort((a, b) => {
      if (a.occurrences !== b.occurrences) {
        return b.occurrences - a.occurrences;
      }
      return b.lastSeen - a.lastSeen;
    });

    return sorted.slice(0, limit).map((note) => ({
      ...note,
      tags: note.tags ? [...note.tags] : undefined,
      lastContext: note.lastContext ? { ...note.lastContext } : undefined,
    }));
  }

  async record(input: SessionNoteInput) {
    if (!input?.key || !input.message) {
      return;
    }

    await this.load();
    const now =
      typeof input.timestamp === "number" && !Number.isNaN(input.timestamp)
        ? input.timestamp
        : Date.now();

    const existing = this.data.notes.find((note) => note.key === input.key);

    if (existing) {
      existing.occurrences += 1;
      existing.lastSeen = now;
      existing.message = input.message || existing.message;
      if (input.suggestion) {
        existing.suggestion = input.suggestion;
      }
      if (input.tags?.length) {
        const merged = new Set([...(existing.tags || []), ...input.tags]);
        existing.tags = Array.from(merged);
      }
      if (input.context) {
        existing.lastContext = { ...input.context };
      }
    } else {
      const record: SessionNoteRecord = {
        id: randomBytes(8).toString("hex"),
        key: input.key,
        message: input.message,
        suggestion: input.suggestion,
        tags: input.tags ? [...input.tags] : undefined,
        occurrences: 1,
        firstSeen: now,
        lastSeen: now,
        lastContext: input.context ? { ...input.context } : undefined,
      };
      this.data.notes.push(record);
    }

    this.#trim();
    await this.#save();
  }

  async clear() {
    await this.load();
    this.data.notes = [];
    await this.#save();
  }

  #normalise(data: StoredNotes | null | undefined): StoredNotes {
    if (!data || typeof data !== "object") {
      return { version: SESSION_NOTES_CURRENT_VERSION, notes: [] };
    }

    const version =
      typeof data.version === "number"
        ? data.version
        : SESSION_NOTES_CURRENT_VERSION;

    const notes = Array.isArray(data.notes)
      ? data.notes
          .filter((note) => note && typeof note === "object")
          .map((note) => ({
            id: String(
              (note as SessionNoteRecord).id || randomBytes(8).toString("hex"),
            ),
            key: String((note as SessionNoteRecord).key || ""),
            message: String((note as SessionNoteRecord).message || ""),
            suggestion:
              typeof (note as SessionNoteRecord).suggestion === "string"
                ? (note as SessionNoteRecord).suggestion
                : undefined,
            tags: Array.isArray((note as SessionNoteRecord).tags)
              ? ((note as SessionNoteRecord).tags as string[]).map((tag) =>
                  String(tag),
                )
              : undefined,
            occurrences:
              typeof (note as SessionNoteRecord).occurrences === "number"
                ? Math.max(
                    1,
                    Math.floor((note as SessionNoteRecord).occurrences),
                  )
                : 1,
            firstSeen:
              typeof (note as SessionNoteRecord).firstSeen === "number"
                ? (note as SessionNoteRecord).firstSeen
                : Date.now(),
            lastSeen:
              typeof (note as SessionNoteRecord).lastSeen === "number"
                ? (note as SessionNoteRecord).lastSeen
                : Date.now(),
            lastContext:
              (note as SessionNoteRecord).lastContext &&
              typeof (note as SessionNoteRecord).lastContext === "object"
                ? { ...(note as SessionNoteRecord).lastContext }
                : undefined,
          }))
      : [];

    return { version, notes };
  }

  #trim() {
    this.data.notes.sort((a, b) => {
      if (a.occurrences !== b.occurrences) {
        return b.occurrences - a.occurrences;
      }
      return b.lastSeen - a.lastSeen;
    });

    if (this.data.notes.length <= this.maxNotes) {
      return;
    }

    this.data.notes = this.data.notes.slice(0, this.maxNotes);
  }

  async #save() {
    const json = JSON.stringify(this.data);
    const encrypted = this.crypto.encrypt(json);
    await this.storage.saveRaw(encrypted);
  }
}
