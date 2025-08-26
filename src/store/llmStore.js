import { create } from "zustand";

const useLLMStore = create((set) => ({
  messages: [],
  isGenerating: false,
  modelStatus: "idle",
  currentModelPath: null,
  addMessage: (message) =>
    set((state) => ({
      messages: [
        ...state.messages,
        {
          id:
            message.id ??
            `${Date.now()}-${Math.random().toString(36).slice(2)}`,
          ...message,
        },
      ],
    })),
  setMessages: (messages) =>
    set({
      messages: messages.map((m) => ({
        id: m.id ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`,
        ...m,
      })),
    }),
  setIsGenerating: (isGenerating) => set({ isGenerating }),
  setModelStatus: (status) => set({ modelStatus: status }),
  setCurrentModelPath: (path) => set({ currentModelPath: path }),
}));

export default useLLMStore;
