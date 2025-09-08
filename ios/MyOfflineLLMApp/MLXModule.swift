import Foundation
import React
import Darwin
// MLXLLM is provided by the Swift package "mlx-swift-examples".
// Guard imports so builds still succeed if SPM fails to resolve.
#if canImport(MLXLLM)
import MLXLLM
#else
import MLX  // fallback to core MLX so project builds; update calls accordingly
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

#if canImport(MLXLLM) || canImport(MLXLMCommon)

/// The native module that exposes MLX-based functionality to the
/// React Native bridge.  It manages an optional `ChatSession` instance
/// and implements the methods expected by the JavaScript side.  All
/// methods dispatch back to the JS thread via promise blocks.
@objc(MLXModule)
public final class MLXModule: NSObject {
  private var chat: MLXCompat.ChatSession?
  /// A simple cache for previously generated prompts.  Stores the
  /// prompt and its generated reply.  When the same prompt is
  /// requested again we return the cached result instead of
  /// re-computing it.
  private var kvCache: [String: String] = [:]
  @objc public static func requiresMainQueueSetup() -> Bool { false }
}

// Conform to the React Native bridge protocol so that this class can
// be instantiated from JavaScript.
extension MLXModule: RCTBridgeModule {
  public static func moduleName() -> String! { "MLXModule" }

  /// Load a model from a folder on disk.  On success a `ChatSession` is
  /// created and stored; on failure the error is passed back to JS.
  @objc(loadModel:resolver:rejecter:)
  public func loadModel(_ modelPath: String,
                        resolver resolve: @escaping RCTPromiseResolveBlock,
                        rejecter reject: @escaping RCTPromiseRejectBlock) {
    do {
      let url = URL(fileURLWithPath: modelPath, isDirectory: true)
      let loader = try MLXCompat.ModelLoader(modelURL: url)
      // Create a session from the loader so we can issue completions.
      let options = MLXCompat.GenerationOptions(maxTokens: 0, temperature: 0)
      self.chat = try MLXCompat.ChatSession(loader: loader, options: options)
      // Clear any cached results whenever a new model is loaded
      self.kvCache.removeAll()
      resolve(true)
    } catch {
      reject("MLX_LOAD_ERR", "Failed to load MLX model: \(error)", error)
    }
  }

  /// Generate text from a prompt.  If the model hasn’t been loaded an
  /// error is returned.  In the stub implementation this simply
  /// returns the prompt back.
  @objc(generate:maxTokens:temperature:resolver:rejecter:)
  public func generate(_ prompt: String,
                       maxTokens: NSNumber,
                       temperature: NSNumber,
                       resolver resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let chat = self.chat else {
      reject("MLX_NOT_READY", "Model not loaded", nil)
      return
    }
    // If we’ve already generated a reply for this prompt, return it
    // immediately.  This avoids recomputing the output for identical
    // inputs.
    if let cached = kvCache[prompt] {
      resolve(cached)
      return
    }
    Task.detached {
      do {
        let opts = MLXCompat.GenerationOptions(maxTokens: maxTokens.intValue,
                                               temperature: Float(truncating: temperature))
        let reply = try await chat.complete(prompt: prompt, options: opts)
        // Store in the cache for subsequent calls
        self.kvCache[prompt] = reply
        resolve(reply)
      } catch {
        reject("MLX_GEN_ERR", "Generation failed: \(error)", error)
      }
    }
  }
}

// MARK: - Convenience APIs matching Android’s surface

extension MLXModule {
  @objc(unloadModel:rejecter:)
  public func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                          rejecter reject: @escaping RCTPromiseRejectBlock) {
    self.chat = nil
    resolve(true)
  }

  @objc(getPerformanceMetrics:rejecter:)
  public func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    // Compute memory usage ratio similar to the implementation in
    // LLM.swift.  Use mach APIs to query the resident memory and
    // normalise it by the physical memory.  If the API call fails
    // default to 0.
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
    // Computing CPU utilisation accurately requires host processor
    // statistics; since these APIs are brittle and platform-specific,
    // we return 0 here for robustness.  Replace this value with a
    // more accurate estimate if needed.
    let cpuUsageRatio: Double = 0.0
    resolve(["memoryUsage": memoryUsageRatio, "cpuUsage": cpuUsageRatio])
  }

  @objc(adjustPerformanceMode:resolver:rejecter:)
  public func adjustPerformanceMode(_ mode: NSString,
                                    resolver resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    // Accept one of a handful of predefined modes.  If the mode is
    // unrecognised return false.  In a real MLX integration these
    // modes would tune the model’s resource usage or accuracy.
    let validModes: Set<String> = ["high_quality", "balanced", "low_power"]
    resolve(validModes.contains(mode as String))
  }

  @objc(embed:resolver:rejecter:)
  public func embed(_ text: NSString,
                    resolver resolve: @escaping RCTPromiseResolveBlock,
                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    // Similar to LLM.swift, compute a normalised embedding by taking
    // the Unicode scalar values of the first 64 characters and
    // dividing by the maximum code point.  This provides a simple,
    // deterministic representation of the text without relying on a
    // machine learning model.
    let scalars = (text as String).unicodeScalars.prefix(64)
    let maxCode = Double(0x10FFFF)
    let vector = scalars.map { Double($0.value) / maxCode }
    resolve(vector)
  }

  @objc(clearKVCache:rejecter:)
  public func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                           rejecter reject: @escaping RCTPromiseRejectBlock) {
    kvCache.removeAll()
    resolve(true)
  }

  @objc(addMessageBoundary:rejecter:)
  public func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                                 rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(true)
  }

  @objc(getKVCacheSize:rejecter:)
  public func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                             rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(kvCache.count)
  }

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

  @objc(generate:maxTokens:temperature:resolver:rejecter:)
  public func generate(_ prompt: String,
                       maxTokens: NSNumber,
                       temperature: NSNumber,
                       resolver resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {
    reject("MLX_NOT_AVAILABLE", "MLXLLM not available", MLXNotAvailable.missingPackage)
  }
}

// MARK: - Convenience APIs matching Android’s surface

extension MLXModule {
  @objc(unloadModel:rejecter:)
  public func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                          rejecter reject: @escaping RCTPromiseRejectBlock) {
    kvCache.removeAll()
    resolve(true)
  }

  @objc(getPerformanceMetrics:rejecter:)
  public func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(["memoryUsage": 0.0, "cpuUsage": 0.0])
  }

  @objc(adjustPerformanceMode:resolver:rejecter:)
  public func adjustPerformanceMode(_ mode: NSString,
                                    resolver resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(false)
  }

  @objc(embed:resolver:rejecter:)
  public func embed(_ text: NSString,
                    resolver resolve: @escaping RCTPromiseResolveBlock,
                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve([])
  }

  @objc(clearKVCache:rejecter:)
  public func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                           rejecter reject: @escaping RCTPromiseRejectBlock) {
    kvCache.removeAll()
    resolve(true)
  }

  @objc(addMessageBoundary:rejecter:)
  public func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                                 rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(true)
  }

  @objc(getKVCacheSize:rejecter:)
  public func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                             rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(kvCache.count)
  }

  @objc(getKVCacheMaxSize:rejecter:)
  public func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock,
                                rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(Int.max)
  }
}
#endif
