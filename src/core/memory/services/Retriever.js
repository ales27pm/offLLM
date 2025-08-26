export default class Retriever {
  constructor(vectorStore, llmService, attentionFn) {
    this.store = vectorStore;
    this.llm = llmService;
    this.attention = attentionFn;
    this.initialized = false;
  }

  async _ensureInit() {
    if (!this.initialized) {
      await this.store.initialize();
      this.initialized = true;
    }
  }

  async retrieve(query, maxResults = 5) {
    await this._ensureInit();
    const qEmb = await this.llm.embed(query);
    const raw = await this.store.searchVectors(qEmb, maxResults * 3);
    const items = raw.map((r) => {
      const node = this.store.nodeMap.get(r.id);
      const meta = r.metadata || node?.metadata || {};
      return {
        emb: node?.vector || [],
        content: `User: ${meta.user}\nAssistant: ${meta.assistant}`,
      };
    });
    if (!items.length) return [];

    const indices = this.attention(
      qEmb,
      items.map((i) => i.emb),
      { numClusters: 3, topK: Math.min(2, items.length) },
    );
    return indices.map((i) => ({ role: "context", content: items[i].content }));
  }
}
