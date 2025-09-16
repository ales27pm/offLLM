import MLXModule from "../../native/MLXModule";

export type ChatTurn = { role: "user" | "assistant"; content: string };

export type LoadOptions = {
  /** HuggingFace model id. If omitted, native code tries tiny fallbacks. */
  modelId?: string;
};

export class MlxChat {
  private history: ChatTurn[] = [];

  async load(opts?: LoadOptions) {
    const ok = await MLXModule.load(opts?.modelId ?? "");
    if (!ok) throw new Error("Failed to load MLX model");
    this.history = [];
    return ok;
  }

  async isLoaded() {
    return MLXModule.isLoaded();
  }

  reset() {
    MLXModule.reset();
    this.history = [];
  }

  unload() {
    MLXModule.unload();
    this.history = [];
  }

  /**
   * Sends a user prompt and returns the assistant reply.
   * The native side keeps multi-turn state; we mirror it in JS for UI.
   */
  async send(prompt: string) {
    this.history.push({ role: "user", content: prompt });
    const reply = await MLXModule.generate(prompt);
    this.history.push({ role: "assistant", content: reply });
    return reply;
  }

  getHistory() {
    return [...this.history];
  }
}

export const mlxChat = new MlxChat();
