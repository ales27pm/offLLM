import { NativeModules, Platform } from 'react-native';
import { getDeviceProfile } from '../utils/deviceUtils';
import { PluginManager } from '../architecture/pluginManager';
import { DependencyInjector } from '../architecture/dependencyInjector';

class LLMService {
  constructor() {
    this.isWeb = Platform.OS === 'web';
    this.isReady = false;
    this.kvCache = {
      tokens: [],
      size: 0,
      maxSize: 512
    };
    
    this.pluginManager = new PluginManager();
    this.dependencyInjector = new DependencyInjector();
    
    if (!this.isWeb) {
      this.nativeModule = NativeModules[Platform.OS === 'ios' ? 'MLXTurboModule' : 'LlamaTurboModule'];
    }
    
    this.deviceProfile = getDeviceProfile();
    this.performanceMetrics = {
      totalInferenceTime: 0,
      inferenceCount: 0,
      averageInferenceTime: 0
    };
    
    this._registerPlugins();
    this._setupDependencyInjection();
  }

  _registerPlugins() {
    this.pluginManager.registerPlugin('sparseAttention', {
      initialize: async () => {
        console.log('Sparse attention plugin initialized');
      },
      replace: {
        'generate': async function(prompt, maxTokens, temperature, options = {}) {
          const useSparse = options.useSparseAttention || 
                           this.deviceProfile.tier === 'low' ||
                           this.kvCache.size > this.kvCache.maxSize * 0.8;
          
          if (this.isWeb) {
            return this._generateWeb(prompt, maxTokens, temperature);
          }
          
          return await this.nativeModule.generate(
            prompt, 
            maxTokens, 
            temperature, 
            useSparse
          );
        }
      }
    });

    this.pluginManager.registerPlugin('adaptiveQuantization', {
      initialize: async () => {
        console.log('Adaptive quantization plugin initialized');
      },
      extend: {
        'LLMService': {
          adjustQuantization: async function() {
            const metrics = await this.getPerformanceMetrics();
            const { averageInferenceTime, memoryUsage } = metrics;
            
            if (averageInferenceTime > 1000 || memoryUsage > 0.8) {
              await this._switchQuantization('Q4_0');
            } else if (averageInferenceTime < 300 && memoryUsage < 0.6) {
              await this._switchQuantization('Q8_0');
            }
          }
        }
      }
    });
  }

  _setupDependencyInjection() {
    this.dependencyInjector.register('deviceProfile', this.deviceProfile);
    this.dependencyInjector.register('performanceMetrics', this.performanceMetrics);
    this.dependencyInjector.register('kvCache', this.kvCache);
  }

  async loadModel(modelPath) {
    try {
      let result;
      
      if (this.isWeb) {
        result = { status: 'loaded', contextSize: 4096, model: modelPath };
      } else {
        result = await this.nativeModule.loadModel(modelPath);
        
        await this.pluginManager.enablePlugin('sparseAttention');
        await this.pluginManager.enablePlugin('adaptiveQuantization');
      }
      
      this.isReady = true;
      this.clearKVCache();
      return result;
    } catch (error) {
      console.error('Failed to load model:', error);
      throw error;
    }
  }

  async generate(prompt, maxTokens = 256, temperature = 0.7, options = {}) {
    if (!this.isReady && !this.isWeb) {
      throw new Error('Model not loaded');
    }

    try {
      const startTime = Date.now();
      
      let response;
      if (this.pluginManager.isPluginEnabled('sparseAttention')) {
        response = await this.pluginManager.execute('generate', 
          [prompt, maxTokens, temperature, options], this);
      } else {
        response = this.isWeb
          ? await this._generateWeb(prompt, maxTokens, temperature)
          : await this.nativeModule.generate(prompt, maxTokens, temperature, false);
      }
      
      const inferenceTime = Date.now() - startTime;
      this.performanceMetrics.totalInferenceTime += inferenceTime;
      this.performanceMetrics.inferenceCount++;
      this.performanceMetrics.averageInferenceTime = 
        this.performanceMetrics.totalInferenceTime / this.performanceMetrics.inferenceCount;
      
      const newTokens = response.text.split(/\s+/).length;
      this.kvCache.size += newTokens;
      
      if (response.kvCacheSize !== undefined) {
        this.kvCache.size = response.kvCacheSize;
      }
      
      if (this.kvCache.size > this.kvCache.maxSize) {
        const excess = this.kvCache.size - this.kvCache.maxSize;
        this.kvCache.size = this.kvCache.maxSize;
      }
      
      if (this.pluginManager.isPluginEnabled('adaptiveQuantization')) {
        setTimeout(() => this.adjustQuantization(), 0);
      }
      
      return {
        ...response,
        kvCacheSize: this.kvCache.size,
        kvCacheMax: response.kvCacheMax || this.kvCache.maxSize,
        inferenceTime
      };
    } catch (error) {
      console.error('Generation failed:', error);
      throw error;
    }
  }

  async getPerformanceMetrics() {
    try {
      if (!this.isWeb) {
        const metrics = await this.nativeModule.getPerformanceMetrics();
        
        return {
          ...this.performanceMetrics,
          ...metrics
        };
      }
      
      return this.performanceMetrics;
    } catch (error) {
      console.error('Failed to get performance metrics:', error);
      return this.performanceMetrics;
    }
  }

  async adjustPerformanceMode(mode) {
    try {
      if (!this.isWeb) {
        await this.nativeModule.adjustPerformanceMode(mode);
        
        switch (mode) {
          case 'low-memory':
            this.kvCache.maxSize = 256;
            break;
          case 'power-saving':
            this.kvCache.maxSize = 512;
            break;
          case 'performance':
            this.kvCache.maxSize = 1024;
            break;
        }
      }
      
      return true;
    } catch (error) {
      console.error('Failed to adjust performance mode:', error);
      return false;
    }
  }

  async embed(text) {
    if (!this.isReady && !this.isWeb) {
      throw new Error('Model not loaded');
    }

    try {
      return this.isWeb
        ? await this._embedWeb(text)
        : await this.nativeModule.embed(text);
    } catch (error) {
      console.error('Embedding failed:', error);
      throw error;
    }
  }

  async clearKVCache() {
    try {
      if (!this.isWeb) {
        await this.nativeModule.clearKVCache();
        await this.nativeModule.addMessageBoundary();
      }
      
      this.kvCache = {
        tokens: [],
        size: 0,
        maxSize: this.deviceProfile.isQuantized ? 768 : 512
      };
      
      return { status: 'cleared', size: 0 };
    } catch (error) {
      console.error('Failed to clear KV cache:', error);
      throw error;
    }
  }

  async getKVCacheSize() {
    try {
      if (!this.isWeb) {
        const size = await this.nativeModule.getKVCacheSize();
        const maxSize = await this.nativeModule.getKVCacheMaxSize();
        return { size, maxSize };
      }
      return { size: this.kvCache.size, maxSize: this.kvCache.maxSize };
    } catch (error) {
      console.error('Failed to get KV cache size:', error);
      return { size: this.kvCache.size, maxSize: this.kvCache.maxSize };
    }
  }
  
  async addMessageBoundary() {
    try {
      if (!this.isWeb) {
        await this.nativeModule.addMessageBoundary();
      }
      return true;
    } catch (error) {
      console.error('Failed to add message boundary:', error);
      return false;
    }
  }
  
  async _generateWeb(prompt, maxTokens, temperature) {
    return {
      text: "Web implementation response",
      tokensGenerated: 50,
      kvCacheSize: 100
    };
  }
  
  async _embedWeb(text) {
    return Array(512).fill(0.5);
  }

  async _switchQuantization(level) {
    console.log(`Switching to ${level} quantization`);
    // Implementation would involve downloading and loading a new model
  }
}

export default new LLMService();
