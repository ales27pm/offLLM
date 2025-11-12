import fs from "fs/promises";
import os from "os";
import path from "path";

import SessionNotesStore from "../src/memory/SessionNotesStore";
import SessionNoteManager from "../src/core/memory/SessionNoteManager";

describe("SessionNotesStore", () => {
  let filePath;

  afterEach(async () => {
    if (filePath) {
      try {
        await fs.unlink(filePath);
      } catch (error) {
        if (error?.code !== "ENOENT") {
          throw error;
        }
      }
      filePath = undefined;
    }
  });

  it("records occurrences and persists notes to disk", async () => {
    filePath = path.join(
      os.tmpdir(),
      `session-notes-${Date.now()}-${Math.random()}.dat`,
    );

    const store = new SessionNotesStore({ filePath, maxNotes: 5 });

    await store.record({
      key: "test-note",
      message: "Initial failure detected",
      suggestion: "Investigate the failure",
    });

    await store.record({
      key: "test-note",
      message: "Initial failure detected",
      suggestion: "Retry with smaller batches",
    });

    const notes = await store.getTopNotes({ limit: 1 });
    expect(notes).toHaveLength(1);
    expect(notes[0].occurrences).toBe(2);
    expect(notes[0].suggestion).toBe("Retry with smaller batches");

    const reloaded = new SessionNotesStore({ filePath, maxNotes: 5 });
    const persisted = await reloaded.getTopNotes({ limit: 1 });
    expect(persisted).toHaveLength(1);
    expect(persisted[0].occurrences).toBe(2);
  });
});

describe("SessionNoteManager", () => {
  let filePath;

  afterEach(async () => {
    if (filePath) {
      try {
        await fs.unlink(filePath);
      } catch (error) {
        if (error?.code !== "ENOENT") {
          throw error;
        }
      }
      filePath = undefined;
    }
  });

  it("surfaces CLI overflow guidance for repeated shell output errors", async () => {
    filePath = path.join(
      os.tmpdir(),
      `session-notes-${Date.now()}-${Math.random()}.dat`,
    );

    const store = new SessionNotesStore({ filePath, maxNotes: 5 });
    const manager = new SessionNoteManager({ store });

    const error = new Error(
      "Error: Output for session 'shell1' contained a line exceeding the max of 4096 bytes (observed at least 8049 bytes).",
    );

    await manager.recordError(error, { step: "shell", command: "grep" });

    let context = await manager.getContextEntries({ limit: 3 });
    expect(context).toHaveLength(1);
    expect(context[0].content).toContain("4096");
    expect(context[0].content).toContain("Mitigation");

    await manager.recordError(error, { step: "shell", command: "grep" });
    context = await manager.getContextEntries({ limit: 3 });
    expect(context[0].content).toContain("2\u00d7");
  });
});
