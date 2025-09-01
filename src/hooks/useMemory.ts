import { useEffect, useRef } from "react";
import VectorMemory from "../memory/VectorMemory";
import { getEnv } from "../config";
import LLMService from "../services/llmService";

export function useMemory() {
  const mem = useRef<VectorMemory | null>(null);

  useEffect(() => {
    if (getEnv("MEMORY_ENABLED") === "true") {
      const init = async () => {
        const m = new VectorMemory();
        await m.load();
        mem.current = m;
      };
      init();
    }
  }, []);

  const recall = async (q: string) => {
    if (!mem.current) return "";
    try {
      const emb = await LLMService.embed(q);
      const res = await mem.current.recall(emb, 3);
      return res.map((r) => r.content).join("\n\n");
    } catch {
      return "";
    }
  };

  const rememberPair = async (text: string, role: "user" | "assistant") => {
    if (!mem.current) return;
    const emb = await LLMService.embed(text);
    await mem.current.remember([
      { vector: emb, content: text, metadata: { role } },
    ]);
  };

  return { recall, rememberPair };
}
