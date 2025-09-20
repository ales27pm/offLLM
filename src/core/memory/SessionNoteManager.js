import SessionNotesStore from "../../memory/SessionNotesStore";
import { deriveNoteFromError } from "./sessionNoteHeuristics";

const DEFAULT_LIMIT = 3;
const DEFAULT_MIN_OCCURRENCES = 1;

const TERMINAL_PUNCTUATION = /[.!?]$/;

export default class SessionNoteManager {
  constructor({
    store,
    limit = DEFAULT_LIMIT,
    minOccurrences = DEFAULT_MIN_OCCURRENCES,
  } = {}) {
    this.store = store || new SessionNotesStore();
    this.limit = limit;
    this.minOccurrences = minOccurrences;
  }

  async getContextEntries(options = {}) {
    const limit =
      typeof options.limit === "number" ? options.limit : this.limit;
    const minOccurrences =
      typeof options.minOccurrences === "number"
        ? options.minOccurrences
        : this.minOccurrences;

    const notes = await this.store.getTopNotes({ limit, minOccurrences });
    return notes.map((note) => this.#formatNote(note));
  }

  async recordError(error, metadata = {}) {
    const entry = deriveNoteFromError(error, metadata);
    if (!entry) {
      return;
    }

    try {
      await this.store.record(entry);
    } catch (storeError) {
      if (process.env.NODE_ENV !== "test") {
        console.warn(
          "[SessionNoteManager] Failed to persist session note",
          storeError,
        );
      }
    }
  }

  async clear() {
    await this.store.clear();
  }

  #formatNote(note) {
    const firstSeenIso = new Date(note.firstSeen).toISOString();
    const occurrenceLabel =
      note.occurrences > 1
        ? `${note.occurrences}\u00d7 since ${firstSeenIso}`
        : `recorded ${firstSeenIso}`;

    const message = this.#ensureSentence(note.message || "");
    const mitigationText = this.#ensureSentence(note.suggestion || "");
    const mitigation = mitigationText ? ` Mitigation: ${mitigationText}` : "";

    return {
      role: "system",
      content: `Session note (${occurrenceLabel}): ${message}${mitigation}`,
      metadata: {
        noteId: note.id,
        key: note.key,
        occurrences: note.occurrences,
        lastSeen: note.lastSeen,
        tags: note.tags,
      },
    };
  }

  #ensureSentence(text) {
    const trimmed = String(text || "").trim();
    if (!trimmed) {
      return trimmed;
    }
    if (TERMINAL_PUNCTUATION.test(trimmed)) {
      return trimmed;
    }
    return `${trimmed}.`;
  }
}
