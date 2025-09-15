import Foundation
import React
import MLX
import MLXLLM        // important pour LLMModel et LanguageModel
import MLXLMCommon   // pour GenerateParameters
import MLXLinalg
import MLXRandom

@objc(MLXModule)
public final class MLXModule: NSObject {
  private var model: LanguageModel?
  private var kvCache: [String: String] = [:]
  private var performanceMode: String = "balanced"

  @objc public static func requiresMainQueueSetup() -> Bool { false }
}

extension MLXModule: RCTBridgeModule {
  public static func moduleName() -> String! { "MLXModule" }

  @objc(loadModel:resolver:rejecter:)
  public func loadModel(_ modelPath: String,
                        resolver resolve: @escaping RCTPromiseResolveBlock,
                        rejecter reject: @escaping RCTPromiseRejectBlock) {
    Task.detached { [weak self] in
      do {
        let url = URL(fileURLWithPath: modelPath, isDirectory: true)
        let config: MLXLLM.ModelConfiguration
        if let reg = MLXLLM.ModelRegistry.lookup(id: url.path) {
          config = reg
        } else {
          config = MLXLLM.ModelConfiguration(id: url.path)
        }
        let loaded = try await MLXLLM.LanguageModel(modelConfiguration: config)
        self?.model = loaded
        self?.kvCache.removeAll()
        resolve(true)
      } catch {
        reject("MLX_LOAD_ERR", "Failed to load MLX model: \(error)", error)
      }
    }
  }

  @objc(generate:maxTokens:temperature:resolver:rejecter:)
  public func generate(_ prompt: NSString,
                       maxTokens: NSNumber,
                       temperature: NSNumber,
                       resolver resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {

    guard let model = self.model else {
      reject("MLX_NOT_READY", "Model not loaded", nil)
      return
    }
    let key = prompt as String
    if let cached = kvCache[key] {
      resolve(cached)
      return
    }

    Task { [weak self] in
      do {
        var params = GenerateParameters()
        params.maxTokens = maxTokens.intValue
        params.temperature = Float(truncating: temperature)
        let stream = try await model.generate(prompt: key, parameters: params)
        var reply = ""
        for try await token in stream {
          reply += token
        }
        await MainActor.run {
          self?.kvCache[key] = reply
          resolve(reply)
        }
      } catch {
        reject("MLX_GEN_ERR", "Generation failed: \(error)", error)
      }
    }
  }
}

extension MLXModule {
  @objc(setPerformanceMode:resolver:rejecter:)
  public func setPerformanceMode(_ mode: NSString,
                                 resolver resolve: @escaping RCTPromiseResolveBlock,
                                 rejecter reject: @escaping RCTPromiseRejectBlock) {
    let valid: Set<String> = ["high_quality", "balanced", "low_power"]
    let value = mode as String
    if valid.contains(value) {
      self.performanceMode = value
      resolve(true)
    } else {
      resolve(false)
    }
  }
}
