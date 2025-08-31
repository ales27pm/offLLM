import { useEffect } from "react";
import Tts from "react-native-tts";
import LLMService from "../services/llmService";
import useLLMStore from "../store/llmStore";
import { useEmotion } from "./useEmotion";
import { useMemory } from "./useMemory";
import { buildPrompt } from "../utils/buildPrompt";

export function useChat() {
  const { addMessage, setIsGenerating } = useLLMStore();
  const { detectText, detectAudio } = useEmotion();
  const { recall, rememberPair } = useMemory();

  useEffect(() => {
    Tts.setDefaultRate(0.53);
    Tts.setDefaultPitch(1.0);
  }, []);

  const send = async (text) => {
    const query = text.trim();
    if (!query) return;
    addMessage({ role: "user", content: query });
    setIsGenerating(true);
    try {
      const [textEm, audioEm, ctx] = await Promise.all([
        Promise.resolve(detectText(query)),
        detectAudio(new Float32Array()), // placeholder: supply actual audio buffer in production
        recall(query),
      ]);
      const prompt = buildPrompt({
        query,
        textEmotion: textEm,
        audioEmotion: audioEm,
        context: ctx,
      });
      const { text: reply } = await LLMService.generate(prompt, 256, 0.7, {
        useSparseAttention: true,
      });
      addMessage({ role: "assistant", content: reply });
      await rememberPair(query, "user");
      await rememberPair(reply, "assistant");
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
      addMessage({ role: "assistant", content: "Error: " + e.message });
    } finally {
      setIsGenerating(false);
    }
  };

  return { send };
}
