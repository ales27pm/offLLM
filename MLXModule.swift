import Foundation
import React
import MLX
import MLXLMCommon
import MLXLinalg
import MLXRandom

@objc(MLXModule)
public final class MLXModule: NSObject {
  private var model: LLMModel?
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
        // Charger via la nouvelle API MLX LLMModel
        self?.model = try await LLMModel.load(.init(id: modelPath))
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

    Task { [weak self, model] in
      do {
        let maxT = max(1, maxTokens.intValue)
        let stream = try await model.generate(prompt: key, maxTokens: maxT)

        var reply = ""
        reply.reserveCapacity(min(maxT * 4, 8192))
        for try await token in stream {
          if Task.isCancelled { return }
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

// API utilitaires (ex. mode de performance) — mémoire locale seulement.
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

  @objc(adjustPerformanceMode:resolver:rejecter:)
  public func adjustPerformanceMode(_ mode: NSString,
                                    resolver resolve: @escaping RCTPromiseResolveBlock,
                                    rejecter reject: @escaping RCTPromiseRejectBlock) {
    self.performanceMode = mode as String
    resolve(false) // placeholder: pas d’effet côté MLX pour l’instant
  }
}

