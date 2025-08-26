import { create } from "zustand";

const useLLMStore = create((set, get) => ({
  messages: [],
  isGenerating: false,
  modelStatus: "idle",
  currentModelPath: null,
  addMessage: (message) =>
    set((state) => ({ messages: [...state.messages, message] })),
  setMessages: (messages) => set({ messages }),
  setIsGenerating: (isGenerating) => set({ isGenerating }),
  setModelStatus: (status) => set({ modelStatus: status }),
  setCurrentModelPath: (path) => set({ currentModelPath: path }),
  generateResponse: async (prompt, llmService) => {
    const { addMessage, setIsGenerating } = get();
    addMessage({ role: "user", content: prompt });
    setIsGenerating(true);
    try {
      const response = await llmService.generate(prompt);
      const text = response?.text ?? response;
      addMessage({ role: "assistant", content: text });
    } catch (error) {
      addMessage({ role: "assistant", content: `Error: ${error.message}` });
    } finally {
      setIsGenerating(false);
    }
  },
}));

export default useLLMStore;
