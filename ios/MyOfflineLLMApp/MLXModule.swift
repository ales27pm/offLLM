import Foundation
import MLX
import MLXLLM
// No `import React` here; we use the bridging header instead.

@objc(MLXModule)
final class MLXModule: NSObject {
  private var chat: ChatSession?
  @objc static func requiresMainQueueSetup() -> Bool { false }
}

extension MLXModule: RCTBridgeModule {
  static func moduleName() -> String! { "MLXModule" }

  @objc(loadModel:resolver:rejecter:)
  func loadModel(_ modelPath: String,
                 resolver: @escaping RCTPromiseResolveBlock,
                 rejecter: @escaping RCTPromiseRejectBlock) {
    do {
      let url = URL(fileURLWithPath: modelPath, isDirectory: true)
      let loader = try ChatModelLoader(modelFolder: url)
      self.chat = try ChatSession(model: loader.model, tokenizer: loader.tokenizer)
      resolver(true)
    } catch {
      rejecter("MLX_LOAD_ERR", "Failed to load MLX model: \(error)", error)
    }
  }

  @objc(generate:maxTokens:temperature:resolver:rejecter:)
  func generate(_ prompt: String,
                maxTokens: NSNumber,
                temperature: NSNumber,
                resolver: @escaping RCTPromiseResolveBlock,
                rejecter: @escaping RCTPromiseRejectBlock) {
    guard let chat = self.chat else {
      rejecter("MLX_NOT_READY", "Model not loaded", nil); return
    }
    Task.detached {
      do {
        let opts = GenerationOptions(
          maxTokens: maxTokens.intValue,
          temperature: Float(truncating: temperature)
        )
        let reply = try await chat.complete(prompt: prompt, options: opts)
        resolver(reply)
      } catch {
        rejecter("MLX_GEN_ERR", "Generation failed: \(error)", error)
      }
    }
  }
}

// --- Parity helpers to match Android API surface (safe placeholders) ---
extension MLXModule {

  @objc(unloadModel:rejecter:)
  func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                   rejecter reject: @escaping RCTPromiseRejectBlock) {
    self.chat = nil
    resolve(true)
  }

  @objc(getPerformanceMetrics:rejecter:)
  func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                             rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve([
      "memoryUsage": 0.5, // placeholder 0..1
      "cpuUsage": 0.5     // placeholder 0..1
    ])
  }

  @objc(adjustPerformanceMode:resolver:rejecter:)
  func adjustPerformanceMode(_ mode: NSString,
                             resolver resolve: @escaping RCTPromiseResolveBlock,
                             rejecter reject: @escaping RCTPromiseRejectBlock) {
    // TODO: wire into MLX tuning
    resolve(true)
  }

  @objc(embed:resolver:rejecter:)
  func embed(_ text: NSString,
             resolver resolve: @escaping RCTPromiseResolveBlock,
             rejecter reject: @escaping RCTPromiseRejectBlock) {
    // TODO: use an MLX embedding model
    resolve([Double]())
  }

  @objc(clearKVCache:rejecter:)
  func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    // TODO: clear decoder KV cache if available
    resolve(true)
  }

  @objc(addMessageBoundary:rejecter:)
  func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                          rejecter reject: @escaping RCTPromiseRejectBlock) {
    // TODO: mark boundary if the model/runtime supports it
    resolve(true)
  }

  @objc(getKVCacheSize:rejecter:)
  func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(0)
  }

  @objc(getKVCacheMaxSize:rejecter:)
  func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock,
                         rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(0)
  }
}
