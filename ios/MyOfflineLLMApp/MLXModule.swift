//
//  MLXModule.swift
//  monGARS
//
//  React Native bridge for on-device generation using swift-transformers.
//  Updated to Hub + Generation APIs (no MLXLLM.ModelConfiguration / LLMModel).
//

import Foundation
import React
import Hub              // from swift-transformers
import Tokenizers       // from swift-transformers
import Generation       // from swift-transformers

@objc(MLXModule)
final class MLXModule: NSObject {

  // MARK: - React export
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // MARK: - State

  // Loaded components
  private var model: any LanguageModel?
  private var tokenizer: any Tokenizer?
  private var generator: TextGenerator?

  // Simple cancel flag for cooperative cancellation
  private var isCancelled = false

  // MARK: - Helpers

  private func assertLoaded() throws {
    guard generator != nil else {
      throw NSError(domain: "MLX", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No model loaded"])
    }
  }
}

// MARK: - React methods

extension MLXModule {

  /// Load a model from a **local directory path** (already downloaded in CI).
  /// `modelPath` should be something like `${WORKSPACE}/models/Qwen2.5-0.5B-Instruct-mlx`
  @objc(loadModel:resolver:rejecter:)
  func loadModel(_ modelPath: String,
                 resolver resolve: @escaping RCTPromiseResolveBlock,
                 rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task(priority: .userInitiated) { [weak self] in
      guard let self = self else { return }

      do {
        let url = URL(fileURLWithPath: modelPath)

        // Hub can load from local dirs that look like HF repos (has config + weights).
        // It returns a LanguageModel + Tokenizer pair suitable for text generation.
        let loaded = try await Hub.loadTextGenerationModel(at: url)

        // Keep strong refs
        self.model = loaded.model
        self.tokenizer = loaded.tokenizer
        self.generator = TextGenerator(model: loaded.model, tokenizer: loaded.tokenizer)

        // Reset cancellation/kvcache-like state (TextGenerator handles caching internally)
        self.isCancelled = false

        resolve(true)
      } catch {
        reject("MLX_LOAD_ERR", "Failed to load model at \(modelPath): \(error.localizedDescription)", error)
      }
    }
  }

  /// Unload everything to free memory (important for CI archiving on device sdk).
  @objc(unloadModel)
  func unloadModel() {
    isCancelled = true
    generator = nil
    model = nil
    tokenizer = nil
  }

  /// Generate text. `key` is the prompt, `maxTokens` is NSNumber for RN bridge.
  /// Returns the full string once finished (streaming can be added later if needed).
  @objc(generate:withMaxTokens:resolver:rejecter:)
  func generate(_ key: String,
                withMaxTokens maxTokens: NSNumber,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task(priority: .userInitiated) { [weak self] in
      guard let self = self else { return }

      do {
        try self.assertLoaded()
        guard let generator = self.generator else {
          throw NSError(domain: "MLX", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Generator not available"])
        }

        self.isCancelled = false

        // Parameters mirror swift-transformers `Generation.Parameters`
        var params = Generation.Parameters()
        params.maxNewTokens = maxTokens.intValue
        params.temperature = 0.7      // sane defaults; tweak if needed
        params.topP = 0.95

        // Generate as a single result (non-streaming)
        let result = try await generator.generate(prompt: key, parameters: params) { [weak self] in
          // cooperative cancellation check
          (self?.isCancelled ?? false)
        }

        resolve(result)
      } catch {
        reject("MLX_GEN_ERR", "Generation failed: \(error.localizedDescription)", error)
      }
    }
  }

  /// Allow JS to cancel an in-flight generation cooperatively.
  @objc(cancel)
  func cancel() {
    isCancelled = true
  }
}
