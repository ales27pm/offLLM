import { createHash } from "crypto";

const KNOWN_ERROR_NOTES = [
  {
    key: "shell-output-4096-limit",
    pattern: /line exceeding the max of 4096 bytes/i,
    message:
      "Shell output exceeded the 4096-byte line limit enforced by the CLI bridge, so results were truncated and the session aborted.",
    suggestion:
      "Chunk long command output (pipe through `rg`, `grep -n`, `sed -n '1,200p'`, `cut -c1-200`, or `head`/`tail`) so no single line exceeds 4 KB.",
    tags: ["shell", "telemetry"],
  },
];

const DEFAULT_FALLBACK_SUGGESTION =
  "Investigate this recurring error, capture the remediation steps, and break workflows into smaller chunks to avoid repeating it.";

const FALLBACK_TAGS = ["error"];

const HASH_PREFIX = "error:";

const MAX_MESSAGE_LENGTH = 1024;

export function deriveNoteFromError(error, metadata = {}) {
  if (!error) {
    return null;
  }

  const rawMessage = extractMessage(error);
  if (!rawMessage) {
    return null;
  }

  const context = {
    ...metadata,
    sourceError: rawMessage,
  };

  const heuristic = KNOWN_ERROR_NOTES.find((entry) =>
    entry.pattern.test(rawMessage),
  );

  if (heuristic) {
    return {
      key: heuristic.key,
      message: heuristic.message,
      suggestion: heuristic.suggestion,
      tags: heuristic.tags,
      context,
    };
  }

  const digest = createHash("sha1")
    .update(rawMessage.slice(0, MAX_MESSAGE_LENGTH))
    .digest("hex");

  const suggestion =
    typeof metadata.suggestion === "string" && metadata.suggestion.trim().length
      ? metadata.suggestion
      : DEFAULT_FALLBACK_SUGGESTION;

  const tags =
    Array.isArray(metadata.tags) && metadata.tags.length
      ? metadata.tags
      : FALLBACK_TAGS;

  return {
    key: `${HASH_PREFIX}${digest}`,
    message: `Recurring error observed: ${rawMessage}`,
    suggestion,
    tags,
    context,
  };
}

function extractMessage(error) {
  if (!error) {
    return "";
  }

  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error) {
    return error.message || String(error);
  }

  if (typeof error.message === "string") {
    return error.message;
  }

  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

export default deriveNoteFromError;
