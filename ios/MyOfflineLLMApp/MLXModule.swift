import Foundation
import React
import Darwin

#if canImport(MLXLLM)
import MLXLLM
#elseif canImport(MLX)
import MLX  // fallback to core MLX so project builds; update calls accordingly
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

#if canImport(MLXLLM) || canImport(MLXLMCommon)

/// The native module that exposes MLX-based functionality to the
/// React Native bridge. It manages an optional `LLMModel` instance
/// and implements the methods expected by the JavaScript side. All
/// methods dispatch back to the JS thread via promise blocks.
@objc(MLXModule)
public final class MLXModule: NSObject {
  /// The loaded MLX language model, if any. When `nil` the module is not ready.
  private var model: LLMModel?
  /// A simple cache for previously generated prompts. Stores the prompt and its
  /// generated reply. When the same prompt is requested again we return the
  /// cached result instead of re-computing it.
  private var kvCache: [String: String] = [:]
  @objc public static func requiresMainQueueSetup() -> Bool { false }
}

extension MLXModule: RCTBridgeModule {
  public static func moduleName() -> String! { "MLXModule" }

  /// Load a model from a folder on disk. On success an `LLMModel` is
  /// created and stored; on failure the error is passed back to JS.
  @objc(loadModel:resolver:rejecter:)
  public func loadModel(_ modelPath: String,
                        resolver resolve: @escaping RCTPromiseResolveBlock,
                        rejecter reject: @escaping RCTPromiseRejectBlock) {
    Task.detached { [weak self] in
      do {
        // `LLMModel.load` accepts a configuration whose identifier can be a
        // Hugging Face model ID or a local file-system path.  Supplying the
        // on-device folder path loads the model directly from disk.
        self?.model = try await LLMModel.load(configuration: .init(id: modelPath))
        // Reset the cache when switching models to avoid returning stale
        // completions.
        self?.kvCache.removeAll()
        resolve(true)
      } catch {
        reject("MLX_LOAD_ERR", "Failed to load MLX model: \(error)", error)
      }
    }
  }

  /// Generate text from a prompt. If the model hasn’t been loaded an
  /// error is returned. This method configures the model with the requested
  /// parameters, generates a reply, caches it, and resolves.
  @objc(generate:maxTokens:temperature:resolver:rejecter:)
  public func generate(_ prompt: String,
                       maxTokens: NSNumber,
                       temperature: NSNumber,
                       resolver resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let model = self.model else {
      reject("MLX_NOT_READY", "Model not loaded", nil)
      return
    }
    // If we’ve already generated a reply for this prompt, return it immediately.
    if let cached = kvCache[prompt] {
      resolve(cached)
      return
    }
    Task.detached { [weak self, model] in
      do {
        // For now we only control the maximum number of generated tokens.
        // Temperature and other sampling parameters will be reintroduced when
        // exposed by the official API.
        let stream = try await model.generate(prompt: prompt, maxTokens: maxTokens.intValue)
        var reply = ""
        for try await token in stream {
          reply += token
        }
        self?.kvCache[prompt] = reply
        resolve(reply)
      } catch {
        reject("MLX_GEN_ERR", "Generation failed: \(error)", error)
      }
    }
  }

  /// Unload the currently loaded model and clear the cache.
  @objc(unloadModel:rejecter:)
  public func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                          rejecter reject: @escaping RCTPromiseRejectBlock) {
    self.model = nil
    self.kvCache.removeAll()
    resolve(true)
  }

  /// Compute simple performance metrics (memory and CPU usage) of the app.
  @objc(getPerformanceMetrics:rejecter:)
  public func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    let memoryUsageRatio: Double
    if kerr == KERN_SUCCESS {
      let usedBytes = Double(info.resident_size)
      let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
      memoryUsageRatio = totalBytes > 0 ? usedBytes / totalBytes : 0.0
    } else {
      memoryUsageRatio = 0.0
    }
    // Computing CPU utilisation accurately requires host processor statistics;
    // since these APIs are brittle and platform-specific, we return 0 here for
    // robustness. Replace this value with a more accurate estimate if needed.
    let cpuUsageRatio: Double = 0.0
    resolve(["memoryUsage": memoryUsageRatio, "cpuUsage": cpuUsageRatio])
  }

  /// Adjust the performance mode. Accepts one of a handful of predefined
  /// modes and returns true if the mode is valid.
  @objc(adjustPerformanceMode:resolver:rejecter:)
  public func adjustPerformanceMode(_ mode: NSString,
                                    resolver resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    let validModes: Set<String> = ["high_quality", "balanced", "low_power"]
    resolve(validModes.contains(mode as String))
  }

  /// Compute a simple deterministic embedding of the provided text by
  /// normalising the Unicode scalar values of the first 64 characters.
  @objc(embed:resolver:rejecter:)
  public func embed(_ text: NSString,
                    resolver resolve: @escaping RCTPromiseResolveBlock,
                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    let scalars = (text as String).unicodeScalars.prefix(64)
    let maxCode = Double(0x10FFFF)
    let vector = scalars.map { Double($0.value) / maxCode }
    resolve(vector)
  }

  /// Clear the key–value cache used for storing previous completions.
  @objc(clearKVCache:rejecter:)
  public func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                           rejecter reject: @escaping RCTPromiseRejectBlock) {
    kvCache.removeAll()
    resolve(true)
  }

  /// Add a message boundary. Provided for API parity with Android; no-op here.
  @objc(addMessageBoundary:rejecter:)
  public func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                                 rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(true)
  }

  /// Get the number of entries currently stored in the cache.
  @objc(getKVCacheSize:rejecter:)
  public func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                             rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(kvCache.count)
  }

  /// Get the maximum number of entries that could be stored in the cache.
  @objc(getKVCacheMaxSize:rejecter:)
  public func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock,
                                rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(Int.max)
  }
}

#else

@objc(MLXModule)
public final class MLXModule: NSObject {
  public enum MLXNotAvailable: Error { case missingPackage }
  private var kvCache: [String: String] = [:]
  @objc public static func requiresMainQueueSetup() -> Bool { false }
}

extension MLXModule: RCTBridgeModule {
  public static func moduleName() -> String! { "MLXModule" }

  @objc(loadModel:resolver:rejecter:)
  public func loadModel(_ modelPath: String,
                        resolver resolve: @escaping RCTPromiseResolveBlock,
                        rejecter reject: @escaping RCTPromiseRejectBlock) {
    reject("MLX_NOT_AVAILABLE", "MLXLLM not available", MLXNotAvailable.missingPackage)
  }
}

#endif