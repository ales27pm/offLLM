import { NativeModules, Platform } from "react-native";
import LLM from "../specs/NativeLLM"; // Turbo (preferred) with legacy fallback
import { getDeviceProfile } from "../utils/deviceUtils";
import { PluginManager } from "../architecture/pluginManager";
import { DependencyInjector } from "../architecture/dependencyInjector";
import { registerLLMPlugins } from "../architecture/pluginSetup";
import { setupLLMDI } from "../architecture/diSetup";
import { ensureModelDownloaded } from "../utils/modelDownloader";
import { MODEL_CONFIG } from "../config/model";

class LLMService {
  #pendingQuantAdjust = null;

  constructor() {
    this.isWeb = Platform.OS === "web";
    this.isReady = false;
    this.modelPath = null;
    this.kvCache = {
      tokens: [],
      size: 0,
      maxSize: 512,
    };

    this.pluginManager = new PluginManager();
    this.dependencyInjector = new DependencyInjector();

    if (!this.isWeb) {
      // Prefer Turbo (if codegen is active), otherwise use legacy bridge modules.
      const legacy =
        NativeModules[Platform.OS === "ios" ? "MLXModule" : "LlamaTurboModule"];
      this.nativeModule = LLM ?? legacy;
    }

    this.deviceProfile = getDeviceProfile();
    this.performanceMetrics = {
      totalInferenceTime: 0,
      inferenceCount: 0,
      averageInferenceTime: 0,
    };

    registerLLMPlugins(this.pluginManager, this);
    setupLLMDI(this.dependencyInjector, this);
  }

  #scheduleQuantizationAdjustment() {
    if (!this.#pendingQuantAdjust) {
      this.#pendingQuantAdjust = new Promise((resolve) => {
        setTimeout(async () => {
          try {
            await this.adjustQuantization();
          } catch (e) {
            console.error("Quantization adjustment failed:", e);
          }
          resolve();
        }, 0);
      }).finally(() => {
        this.#pendingQuantAdjust = null;
      });
    }
    return this.#pendingQuantAdjust;
  }

  async loadConfiguredModel() {
    if (this.isWeb || this.isReady) {
      return true;
    }
    try {
      const path = await ensureModelDownloaded(MODEL_CONFIG.url, {
        checksum: MODEL_CONFIG.checksum,
      });
      await this.loadModel(path);
      this.modelPath = path;
      return true;
    } catch (error) {
      console.error("Failed to load configured model:", error);
      return false;
    }
  }

  async loadModel(modelPath) {
    try {
      let result;

      // For web builds we simulate a loaded model.
      if (this.isWeb) {
        result = { status: "loaded", contextSize: 4096, model: modelPath };
      } else {
        // On Android the native module expects an options object as the second
        // argument. On iOS the native module only accepts a single argument. To
        // avoid a signature mismatch we pass an empty options object on
        // Android and omit it on iOS.
        if (Platform.OS === "android") {
          result = await this.nativeModule.loadModel(modelPath, {
            contextSize: 4096,
          });
        } else {
          result = await this.nativeModule.loadModel(modelPath);
        }

        // Enable built‑in plugins after loading the model. Sparse attention
        // allows the model to handle longer contexts efficiently and adaptive
        // quantization adjusts precision based on performance metrics.
        await this.pluginManager.enablePlugin("sparseAttention");
        await this.pluginManager.enablePlugin("adaptiveQuantization");
      }

      this.isReady = true;
      this.modelPath = modelPath;
      await this.clearKVCache();
      return result;
    } catch (error) {
      console.error("Failed to load model:", error);
      throw error;
    }
  }

  async generate(prompt, maxTokens = 256, temperature = 0.7, options = {}) {
    if (!this.isWeb && !this.isReady) {
      const loaded = await this.loadConfiguredModel();
      if (!loaded) {
        throw new Error("Model not loaded");
      }
    }

    try {
      const startTime = Date.now();

      let response;
      if (this.pluginManager.isPluginEnabled("sparseAttention")) {
        response = await this.pluginManager.execute(
          "generate",
          [prompt, maxTokens, temperature, options],
          this,
        );
      } else {
        if (this.isWeb) {
          response = await this.generateWeb(prompt, maxTokens, temperature);
        } else if (Platform.OS === "ios") {
          response = await this.nativeModule.generate(prompt);
        } else {
          const generateOptions = {
            maxTokens,
            temperature,
            ...options,
          };
          response = await this.nativeModule.generate(prompt, generateOptions);
        }
      }

      if (typeof response === "string") {
        response = { text: response };
      }

      const inferenceTime = Date.now() - startTime;
      this.performanceMetrics.totalInferenceTime += inferenceTime;
      this.performanceMetrics.inferenceCount++;
      this.performanceMetrics.averageInferenceTime =
        this.performanceMetrics.totalInferenceTime /
        this.performanceMetrics.inferenceCount;

      const newTokens = response.text.split(/\s+/).length;
      this.kvCache.size += newTokens;

      if (response.kvCacheSize !== undefined) {
        this.kvCache.size = response.kvCacheSize;
      }

      if (this.kvCache.size > this.kvCache.maxSize) {
        const excess = this.kvCache.size - this.kvCache.maxSize;
        this.kvCache.tokens = this.kvCache.tokens.slice(excess);
        this.kvCache.size = this.kvCache.maxSize;
      }

      if (this.pluginManager.isPluginEnabled("adaptiveQuantization")) {
        await this.#scheduleQuantizationAdjustment();
      }

      return {
        ...response,
        kvCacheSize: this.kvCache.size,
        kvCacheMax: response.kvCacheMax || this.kvCache.maxSize,
        inferenceTime,
      };
    } catch (error) {
      console.error("Generation failed:", error);
      throw error;
    }
  }

  async getPerformanceMetrics() {
    try {
      if (!this.isWeb) {
        const metrics = this.nativeModule?.getPerformanceMetrics
          ? await this.nativeModule.getPerformanceMetrics()
          : { memoryUsage: undefined, cpuUsage: undefined };

        return {
          ...this.performanceMetrics,
          ...metrics,
        };
      }

      return this.performanceMetrics;
    } catch (error) {
      console.error("Failed to get performance metrics:", error);
      return this.performanceMetrics;
    }
  }

  async adjustPerformanceMode(mode) {
    try {
      if (!this.isWeb) {
        if (this.nativeModule?.adjustPerformanceMode) {
          await this.nativeModule.adjustPerformanceMode(mode);
        }

        switch (mode) {
          case "low-memory":
            this.kvCache.maxSize = 256;
            break;
          case "power-saving":
            this.kvCache.maxSize = 512;
            break;
          case "performance":
            this.kvCache.maxSize = 1024;
            break;
        }
      }

      return true;
    } catch (error) {
      console.error("Failed to adjust performance mode:", error);
      return false;
    }
  }

  async embed(text) {
    if (!this.isReady && !this.isWeb) {
      throw new Error("Model not loaded");
    }

    try {
      return this.isWeb
        ? await this._embedWeb(text)
        : this.nativeModule?.embed
          ? await this.nativeModule.embed(text)
          : null;
    } catch (error) {
      console.error("Embedding failed:", error);
      throw error;
    }
  }

  async clearKVCache() {
    try {
      if (!this.isWeb) {
        if (this.nativeModule?.clearKVCache)
          await this.nativeModule.clearKVCache();
        if (this.nativeModule?.addMessageBoundary) {
          await this.nativeModule.addMessageBoundary();
        }
      }

      this.kvCache = {
        tokens: [],
        size: 0,
        maxSize: this.deviceProfile.isQuantized ? 768 : 512,
      };

      return { status: "cleared", size: 0 };
    } catch (error) {
      console.error("Failed to clear KV cache:", error);
      throw error;
    }
  }

  async getKVCacheSize() {
    try {
      if (!this.isWeb) {
        const size = this.nativeModule?.getKVCacheSize
          ? await this.nativeModule.getKVCacheSize()
          : 0;
        const maxSize = this.nativeModule?.getKVCacheMaxSize
          ? await this.nativeModule.getKVCacheMaxSize()
          : 0;
        return { size, maxSize };
      }
      return { size: this.kvCache.size, maxSize: this.kvCache.maxSize };
    } catch (error) {
      console.error("Failed to get KV cache size:", error);
      return { size: this.kvCache.size, maxSize: this.kvCache.maxSize };
    }
  }

  async addMessageBoundary() {
    try {
      if (!this.isWeb) {
        if (this.nativeModule?.addMessageBoundary) {
          await this.nativeModule.addMessageBoundary();
        }
      }
      return true;
    } catch (error) {
      console.error("Failed to add message boundary:", error);
      return false;
    }
  }

  async generateWeb(_prompt, _maxTokens, _temperature) {
    return {
      text: "Web implementation response",
      tokensGenerated: 50,
      kvCacheSize: 100,
    };
  }

  async _embedWeb(_text) {
    return Array(512).fill(0.5);
  }

  async _switchQuantization(level) {
    console.log(`Switching to ${level} quantization`);
    // Implementation would involve downloading and loading a new model
  }

  /**
   * Dynamically adjust the quantization level of the currently loaded model.
   * This method is called by the adaptiveQuantization plugin. It has been
   * implemented directly on the LLMService instance so that it can be
   * accessed without relying on plugin extension mechanics. When the average
   * inference time is high or memory usage is elevated, the model is
   * downgraded to a lower precision (e.g. Q4_0) to save resources. When
   * performance is excellent, the model may be upgraded to a higher
   * precision (e.g. Q8_0) for improved accuracy. The heuristics here can be
   * tuned based on empirical measurements.
   */
  async adjustQuantization() {
    try {
      const { averageInferenceTime, memoryUsage } =
        await this.getPerformanceMetrics();
      // Use conservative defaults if memoryUsage is undefined (e.g. on iOS)
      const mem = typeof memoryUsage === "number" ? memoryUsage : 0.5;
      if (averageInferenceTime > 1000 || mem > 0.8) {
        await this._switchQuantization("Q4_0");
      } else if (averageInferenceTime < 300 && mem < 0.6) {
        await this._switchQuantization("Q8_0");
      }
    } catch (error) {
      console.warn("Adaptive quantization adjustment failed:", error);
    }
  }
}

export default new LLMService();
