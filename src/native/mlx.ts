import {
  NativeModules,
  NativeEventEmitter,
  EmitterSubscription,
} from "react-native";

const { MLXModule, MLXEvents } = NativeModules as any;

type Options = { topK?: number; temperature?: number };

export async function load(modelID?: string): Promise<{ id: string }> {
  return MLXModule.load?.(modelID) ?? { id: "unknown" };
}

export function reset() {
  MLXModule.reset?.();
}

export function unload() {
  MLXModule.unload?.();
}

export function stop() {
  MLXModule.stop?.();
}

export async function generate(
  prompt: string,
  options?: Options,
): Promise<string> {
  return MLXModule.generate?.(prompt, options ?? {});
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
  options?: Options,
) {
  const subs: EmitterSubscription[] = [];
  subs.push(
    emitter.addListener("mlxToken", (e: { text: string }) =>
      handlers.onToken?.(e.text),
    ),
  );
  subs.push(
    emitter.addListener("mlxCompleted", () => handlers.onCompleted?.()),
  );
  subs.push(emitter.addListener("mlxStopped", () => handlers.onStopped?.()));
  subs.push(
    emitter.addListener("mlxError", (e: { code: string; message: string }) =>
      handlers.onError?.(e.code, e.message),
    ),
  );

  try {
    await MLXModule.startStream?.(prompt, options ?? {});
  } catch (e: any) {
    handlers.onError?.(e?.code ?? "ESTREAM", e?.message ?? String(e));
    subs.forEach((s) => s.remove());
    throw e;
  }

  // hand back an unsubscribe
  return () => subs.forEach((s) => s.remove());
}
