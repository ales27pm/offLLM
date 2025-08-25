import { NativeModules, Platform } from 'react-native';
import LLMService from './llmService';
import { cosineSimilarity } from '../utils/vectorUtils';
import { applySparseAttention } from '../utils/sparseAttention';

export class ContextEvaluator {
  constructor() {
    this.relevanceThreshold = 0.65;
    this.qualityThreshold = 0.7;
    this.useHierarchicalAttention = true;
  }

  async evaluateContext(query, contextItems) {
    if (!contextItems || contextItems.length === 0) return [];
    
    if (this.useHierarchicalAttention && contextItems.length > 10) {
      return this._evaluateWithHierarchicalAttention(query, contextItems);
    }
    
    const relevantContext = contextItems.filter(item => 
      item.similarity >= this.relevanceThreshold
    );
    
    const topContext = relevantContext
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, 3);
    
    if (topContext.length === 0) return [];
    
    const deviceMemory = await this._getDeviceMemory();
    if (deviceMemory < 3000) {
      return topContext.map(item => ({
        ...item,
        qualityScore: item.similarity,
        isHighQuality: item.similarity >= this.qualityThreshold
      }));
    }
    
    return await this._assessContextQuality(query, topContext);
  }

  async _evaluateWithHierarchicalAttention(query, contextItems) {
    const queryEmbedding = await LLMService.embed(query);
    
    const clusteredContext = this._clusterContextItems(contextItems);
    const selectedContext = await applySparseAttention(
      queryEmbedding, 
      clusteredContext,
      { numClusters: 3, topK: 2 }
    );
    
    return await this._assessContextQuality(query, selectedContext);
  }

  _clusterContextItems(contextItems) {
    const clusters = [];
    
    for (const item of contextItems) {
      let addedToCluster = false;
      
      for (const cluster of clusters) {
        const clusterSimilarity = cosineSimilarity(
          item.embedding, 
          cluster.center
        );
        
        if (clusterSimilarity > 0.7) {
          cluster.items.push(item);
          cluster.center = cluster.items.reduce((sum, i) => {
            return sum.map((val, idx) => val + i.embedding[idx]);
          }, new Array(item.embedding.length).fill(0))
          .map(val => val / cluster.items.length);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        clusters.push({
          center: [...item.embedding],
          items: [item]
        });
      }
    }
    
    return clusters;
  }

  async _assessContextQuality(query, contextItems) {
    const qualityResults = [];
    
    for (const item of contextItems) {
      try {
        let qualityScore = item.similarity;
        
        if (item.metadata.timestamp) {
          const age = Date.now() - new Date(item.metadata.timestamp).getTime();
          const ageFactor = Math.max(0.7, 1 - age / (30 * 24 * 60 * 60 * 1000));
          qualityScore *= ageFactor;
        }
        
        if (item.metadata.source === 'knowledge_base') {
          qualityScore *= 1.1;
        }
        
        qualityResults.push({
          ...item,
          qualityScore,
          isHighQuality: qualityScore >= this.qualityThreshold
        });
      } catch (error) {
        console.error('Context quality assessment failed:', error);
        qualityResults.push({
          ...item,
          qualityScore: item.similarity,
          isHighQuality: item.similarity >= this.qualityThreshold
        });
      }
    }
    
    return qualityResults;
  }

  async _getDeviceMemory() {
    try {
      if (Platform.OS === 'ios') {
        return NativeModules.DeviceInfo?.getTotalMemory?.() || 2000;
      } else {
        return NativeModules.DeviceInfo?.totalMemory?.() || 2000;
      }
    } catch (error) {
      return 2000;
    }
  }

  prioritizeContext(contextItems) {
    if (!contextItems || contextItems.length === 0) return [];
    
    return contextItems
      .sort((a, b) => {
        const qualityDiff = (b.qualityScore || b.similarity) - (a.qualityScore || a.similarity);
        if (Math.abs(qualityDiff) > 0.05) return qualityDiff;
        
        try {
          const aTime = a.metadata?.timestamp ? new Date(a.metadata.timestamp).getTime() : 0;
          const bTime = b.metadata?.timestamp ? new Date(b.metadata.timestamp).getTime() : 0;
          return bTime - aTime;
        } catch (e) {
          return 0;
        }
      })
      .filter(item => item.isHighQuality)
      .slice(0, 2);
  }
}

export class ContextEngineer {
  constructor() {
    this.contextEvaluator = new ContextEvaluator();
    this.maxContextTokens = 768;
    this.conversationSummaryLength = 128;
    this.useDynamicTokenBudgeting = true;
  }

  async engineerContext(query, conversationHistory) {
    const { maxContextTokens, conversationSummaryLength } = await this._getDeviceConfig();
    this.maxContextTokens = maxContextTokens;
    this.conversationSummaryLength = conversationSummaryLength;
    
    const tokenBudget = this.useDynamicTokenBudgeting 
      ? await this._calculateDynamicTokenBudget(query, conversationHistory)
      : { maxContextTokens: this.maxContextTokens };
    
    if (this._requiresHierarchicalAttention(query, conversationHistory)) {
      return this._hierarchicalContextProcessing(query, conversationHistory, tokenBudget);
    }
    
    return this._standardContextProcessing(query, conversationHistory, tokenBudget);
  }

  async _calculateDynamicTokenBudget(query, conversationHistory) {
    const deviceProfile = await this._getDeviceProfile();
    const queryComplexity = this._assessQueryComplexity(query);
    
    let baseTokens = deviceProfile.tier === 'high' ? 1024 : 512;
    
    if (queryComplexity === 'high') {
      baseTokens = Math.min(baseTokens, 768);
    } else if (queryComplexity === 'low') {
      baseTokens = Math.min(baseTokens, 1024);
    }
    
    if (conversationHistory.length > 10) {
      baseTokens = Math.max(256, baseTokens * 0.7);
    }
    
    return {
      maxContextTokens: baseTokens,
      queryTokens: Math.floor(baseTokens * 0.2),
      contextTokens: Math.floor(baseTokens * 0.5),
      historyTokens: Math.floor(baseTokens * 0.3)
    };
  }

  _requiresHierarchicalAttention(query, conversationHistory) {
    return query.length > 100 || 
           conversationHistory.length > 10 ||
           this._assessQueryComplexity(query) === 'high';
  }

  async _hierarchicalContextProcessing(query, conversationHistory, tokenBudget) {
    const queryEmbedding = await LLMService.embed(query);
    
    const relevantChunks = await this._retrieveRelevantChunksSparse(
      queryEmbedding, 
      Math.floor(tokenBudget.contextTokens / 100)
    );
    
    const conversationSummary = await this._summarizeConversationHierarchically(
      conversationHistory, 
      tokenBudget.historyTokens
    );
    
    const availableContextTokens = tokenBudget.maxContextTokens - 
                                  conversationSummary.tokenCount - 
                                  tokenBudget.queryTokens;
    
    const selectedContext = await this._selectContextWithinBudgetSparse(
      relevantChunks, 
      availableContextTokens
    );
    
    return {
      contextPrompt: this._assembleHierarchicalContext(
        query, 
        selectedContext, 
        conversationSummary
      ),
      tokenUsage: {
        total: tokenBudget.maxContextTokens,
        context: selectedContext.tokenCount,
        conversation: conversationSummary.tokenCount,
        query: tokenBudget.queryTokens
      },
      usedSparseAttention: true
    };
  }

  async _retrieveRelevantChunksSparse(queryEmbedding, limit) {
    try {
      const results = await vectorStore.searchVectorsSparse(
        queryEmbedding, 
        limit,
        { useHierarchical: true, numClusters: 3 }
      );
      return results;
    } catch (error) {
      console.error('Sparse retrieval failed, falling back to standard:', error);
      return await vectorStore.searchVectors(queryEmbedding, limit);
    }
  }

  async _summarizeConversationHierarchically(conversationHistory, maxTokens) {
    const conversationText = conversationHistory
      .map(m => `${m.role === 'user' ? 'User' : 'Assistant'}: ${m.content}`)
      .join('\n');
      
    try {
      const summaryPrompt = `Summarize this conversation history concisely within ${maxTokens} tokens:\n\n${conversationText}\n\nSummary:`;
      
      const summaryResult = await LLMService.generate(
        summaryPrompt, 
        maxTokens, 
        0.3
      );
      
      return {
        text: summaryResult.text,
        tokenCount: this._estimateTokens(summaryResult.text)
      };
    } catch (error) {
      console.error('Hierarchical summarization failed:', error);
      return {
        text: conversationHistory.slice(-2).map(m => m.content).join('\n'),
        tokenCount: this._estimateTokens(conversationHistory.slice(-2).map(m => m.content).join('\n'))
      };
    }
  }

  _estimateTokens(text) {
    return Math.ceil(text.length / 4);
  }

  _assessQueryComplexity(query) {
    let score = query.length / 100;
    if (query.match(/\b(explain|analyze|reason|complex)\b/i)) score += 5;
    return score > 5 ? 'high' : score > 2 ? 'medium' : 'low';
  }

  async _getDeviceConfig() {
    const deviceMemory = await this._getDeviceMemory();
    const isLowEnd = deviceMemory < 3000;
    
    if (isLowEnd) {
      return {
        maxContextTokens: 512,
        conversationSummaryLength: 96
      };
    } else if (Platform.OS === 'ios') {
      return {
        maxContextTokens: 1024,
        conversationSummaryLength: 160
      };
    } else {
      return {
        maxContextTokens: 768,
        conversationSummaryLength: 128
      };
    }
  }

  async _getDeviceMemory() {
    try {
      if (Platform.OS === 'ios') {
        return NativeModules.DeviceInfo?.getTotalMemory?.() || 2000;
      } else {
        return NativeModules.DeviceInfo?.totalMemory?.() || 2000;
      }
    } catch (error) {
      return 2000;
    }
  }

  async _getDeviceProfile() {
    try {
      const totalMemory = Platform.OS === 'ios' 
        ? NativeModules.DeviceInfo?.getTotalMemory?.() 
        : NativeModules.DeviceInfo?.totalMemory?.() || 2000;
      
      let tier = 'low';
      if (totalMemory >= 6000) {
        tier = 'high';
      } else if (totalMemory >= 3000) {
        tier = 'mid';
      }
      
      return {
        tier,
        totalMemory
      };
    } catch (error) {
      return {
        tier: 'low',
        totalMemory: 2000
      };
    }
  }
}
