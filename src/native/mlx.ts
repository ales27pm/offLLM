import {
  NativeModules,
  NativeEventEmitter,
  EmitterSubscription,
  Platform,
} from "react-native";
import MLXModule, { GenerateOptions } from "./MLXModule";

const { MLXEvents } = NativeModules;

const EVENTS_LINK_ERR =
  `MLXEvents: native event emitter not linked. ` +
  (Platform.OS === "ios"
    ? "Ensure MLXEvents.swift is compiled into the iOS target."
    : "This emitter is available on iOS only.");

if (!MLXEvents) {
  throw new Error(EVENTS_LINK_ERR);
}

export async function load(modelID?: string): Promise<{ id: string }> {
  return MLXModule.load(modelID);
}

export function reset() {
  MLXModule.reset();
}

export function unload() {
  MLXModule.unload();
}

export function stop() {
  MLXModule.stop();
}

export async function generate(
  prompt: string,
  options?: GenerateOptions,
): Promise<string> {
  return MLXModule.generate(prompt, options ?? {});
}

// Streaming API
const emitter = new NativeEventEmitter(MLXEvents);
export type StreamHandlers = {
  onToken?: (t: string) => void;
  onCompleted?: () => void;
  onError?: (code: string, message: string) => void;
  onStopped?: () => void;
};

export async function startStream(
  prompt: string,
  handlers: StreamHandlers = {},
  options?: GenerateOptions,
) {
  const subs: EmitterSubscription[] = [];
  let cleaned = false;
  let errorNotified = false;

  const cleanup = () => {
    if (cleaned) {
      return;
    }
    cleaned = true;
    subs.forEach((s) => s.remove());
    subs.length = 0;
  };

  const notifyError = (code: string, message: string) => {
    if (!errorNotified) {
      errorNotified = true;
      handlers.onError?.(code, message);
    }
    cleanup();
  };

  subs.push(
    emitter.addListener("mlxToken", (e: { text: string }) =>
      handlers.onToken?.(e.text),
    ),
  );
  subs.push(
    emitter.addListener("mlxCompleted", () => {
      handlers.onCompleted?.();
      cleanup();
    }),
  );
  subs.push(
    emitter.addListener("mlxStopped", () => {
      handlers.onStopped?.();
      cleanup();
    }),
  );
  subs.push(
    emitter.addListener("mlxError", (e: { code: string; message: string }) =>
      notifyError(e.code, e.message),
    ),
  );

  try {
    await MLXModule.startStream(prompt, options ?? {});
  } catch (e: any) {
    notifyError(e?.code ?? "ESTREAM", e?.message ?? String(e));
    throw e;
  }

  // hand back an unsubscribe
  return () => cleanup();
}
