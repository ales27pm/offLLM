import Foundation
import React
import MLXLLM

@objc(MLXModule)
public final class MLXModule: NSObject {
  private var model: LanguageModel?
  private var kvCache: [String: String] = [:]
  private let cacheLock = NSLock()
  private var performanceMode: String = "balanced"

  @objc public static func requiresMainQueueSetup() -> Bool { false }
}

extension MLXModule: RCTBridgeModule {
  public static func moduleName() -> String! { "MLXModule" }

  @objc(loadModel:resolver:rejecter:)
  public func loadModel(_ modelPath: String,
                        resolver resolve: @escaping RCTPromiseResolveBlock,
                        rejecter reject: @escaping RCTPromiseRejectBlock) {
    Task { [weak self] in
      do {
        // Charge le modèle MLX depuis un chemin local en utilisant la nouvelle API.
        let url = URL(fileURLWithPath: modelPath, isDirectory: true)
        let cfg: MLXLLM.ModelConfiguration
        if let regCfg = MLXLLM.ModelRegistry.lookup(id: modelPath) {
          cfg = regCfg
        } else {
          cfg = .init(directory: url)
        }
        self?.model = try await MLXLLM.LanguageModel(modelConfiguration: cfg)
        self?.cacheLock.lock()
        self?.kvCache.removeAll()
        self?.cacheLock.unlock()
        await MainActor.run { resolve(true) }
      } catch {
        await MainActor.run {
          reject("MLX_LOAD_ERR", "Failed to load MLX model: \(error)", error)
        }
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
    guard maxTokens.intValue > 0 else {
      reject("MLX_INVALID_ARGS", "maxTokens must be > 0", nil)
      return
    }
    let key = prompt as String
    let cacheKey = "\(key)|mt=\(maxTokens.intValue)|temp=\(String(format: "%.2f", temperature.doubleValue))"
    cacheLock.lock()
    if let cached = kvCache[cacheKey] {
      cacheLock.unlock()
      resolve(cached)
      return
    }
    cacheLock.unlock()

    Task { [weak self, model, cacheKey] in
      do {
        // Note : pour l’instant on ignore la température; la nouvelle API n’expose pas encore ce paramètre.
        let stream = try await model.generate(prompt: key, maxTokens: maxTokens.intValue)
        var reply = ""
        for try await token in stream {
          if Task.isCancelled { break }
          reply += token
        }
        self?.cacheLock.lock()
        self?.kvCache[cacheKey] = reply
        self?.cacheLock.unlock()
        await MainActor.run { resolve(reply) }
      } catch {
        await MainActor.run {
          reject("MLX_GEN_ERR", "Generation failed: \(error)", error)
        }
      }
    }
  }
}

// Optionnel : mémorisation du mode de performance sans toucher au modèle MLX.
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
