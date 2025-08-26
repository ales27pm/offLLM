import { useRef, useEffect } from "react";
import Tts from "react-native-tts";
import LLMService from "../services/llmService";
import useLLMStore from "../store/llmStore";
import VectorMemory from "../memory/VectorMemory";
import ProsodyDetector from "../emotion/ProsodyDetector";
import { getEnv } from "../config";

export function useChat() {
  const { messages, addMessage, setIsGenerating } = useLLMStore();
  const memoryRef = useRef(null);
  const prosodyRef = useRef(new ProsodyDetector());

  useEffect(() => {
    Tts.setDefaultRate(0.53);
    Tts.setDefaultPitch(1.0);
  }, []);

  const initVectorStore = async () => {
    if (getEnv("MEMORY_ENABLED") === "true") {
      const vm = new VectorMemory();
      await vm.load();
      memoryRef.current = vm;
    }
  };

  const detectEmotion = (text) => {
    const lower = text.toLowerCase();
    const checks = {
      happy: ["happy", "glad", "joy", "excited", "awesome"],
      sad: ["sad", "unhappy", "depressed", "down"],
      angry: ["angry", "mad", "furious", "annoyed", "frustrated"],
      scared: ["scared", "afraid", "fear", "nervous"],
      surprised: ["surprised", "shocked"],
    };
    for (const emotion of Object.keys(checks)) {
      if (checks[emotion].some((word) => lower.includes(word))) {
        return emotion;
      }
    }
    return null;
  };

  const getContext = async (query) => {
    if (!memoryRef.current) {
      console.warn(
        "Context retrieval failed: vector store is not initialized.",
      );
      return "";
    }
    try {
      const embedding = await LLMService.embed(query);
      const results = await memoryRef.current.recall(embedding, 3);
      return results.map((r) => r.content).join("\n\n");
    } catch (e) {
      console.warn("Context retrieval failed:", e);
      return "";
    }
  };

  const send = async (text) => {
    const query = text.trim();
    if (!query) return;
    addMessage({ role: "user", content: query });
    try {
      setIsGenerating(true);
      const emotion = detectEmotion(query);
      let audioEmotion = null;
      try {
        const res = await prosodyRef.current.analyze(new Float32Array());
        if (res.confidence > 0.5) audioEmotion = res.emotion;
      } catch (e) {
        audioEmotion = null;
      }
      const context = await getContext(query);
      let prompt = query;
      const finalEmotion = audioEmotion || emotion;
      if (finalEmotion) {
        prompt = `The user sounds ${finalEmotion}. ${prompt}`;
      }
      if (context) {
        prompt = `Context:\n${context}\n\n${prompt}`;
      }
      const response = await LLMService.generate(prompt, 256, 0.7, {
        useSparseAttention: true,
      });
      const reply = response.text;
      addMessage({ role: "assistant", content: reply });
      if (memoryRef.current) {
        const userEmb = await LLMService.embed(query);
        await memoryRef.current.remember([
          { vector: userEmb, content: query, metadata: { role: "user" } },
        ]);
        const respEmb = await LLMService.embed(reply);
        await memoryRef.current.remember([
          { vector: respEmb, content: reply, metadata: { role: "assistant" } },
        ]);
      }
      Tts.stop();
      const speechText = reply.replace(
        /([.?!])\s+/g,
        '$1 <break time="500ms"/> ',
      );
      Tts.speak(speechText, {
        androidParams: {
          KEY_PARAM_PAN: 0,
          KEY_PARAM_VOLUME: 0.9,
          KEY_PARAM_STREAM: "STREAM_MUSIC",
        },
      });
    } catch (e) {
      console.error("Error generating response:", e);
      addMessage({
        role: "assistant",
        content: "Error: " + e.message,
      });
    } finally {
      setIsGenerating(false);
    }
  };

  return { messages, send, initVectorStore };
}
