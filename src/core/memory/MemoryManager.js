import { HNSWVectorStore } from "../../utils/hnswVectorStore";
import LLMService from "../../services/llmService";
import { applySparseAttention } from "../../utils/sparseAttention";

export class MemoryManager {
  constructor() {
    this.vectorStore = new HNSWVectorStore();
    this.conversationHistory = [];
    this.initialized = false;
  }

  async _ensureInitialized() {
    if (!this.initialized) {
      await this.vectorStore.initialize();
      this.initialized = true;
    }
  }

  async addInteraction(userPrompt, aiResponse, toolResults = []) {
    await this._ensureInitialized();
    const embedding = await LLMService.embed(userPrompt);
    const content = `User: ${userPrompt}\nAssistant: ${aiResponse}`;
    await this.vectorStore.addVector(content, embedding, {
      user: userPrompt,
      assistant: aiResponse,
      tools: toolResults,
      timestamp: new Date().toISOString(),
    });

    this.conversationHistory.push({ role: "user", content: userPrompt });
    this.conversationHistory.push({ role: "assistant", content: aiResponse });
    if (this.conversationHistory.length > 20) {
      this.conversationHistory = this.conversationHistory.slice(-20);
    }
  }

  async retrieve(query, maxResults = 5) {
    await this._ensureInitialized();
    const queryEmbedding = await LLMService.embed(query);
    const results = await this.vectorStore.searchVectors(
      queryEmbedding,
      maxResults * 3
    );

    const contextItems = results.map((r) => {
      const node = this.vectorStore.nodeMap.get(r.id);
      return {
        embedding: node?.vector || [],
        content: `User: ${r.metadata.user}\nAssistant: ${r.metadata.assistant}`,
      };
    });

    if (contextItems.length === 0) {
      return [];
    }

    const selected = applySparseAttention(
      queryEmbedding,
      contextItems.map((i) => i.embedding),
      { numClusters: 3, topK: Math.min(2, contextItems.length) }
    );

    return selected.map((index) => ({
      role: "context",
      content: contextItems[index].content,
    }));
  }

  getConversationHistory() {
    return this.conversationHistory;
  }
}

export default MemoryManager;
