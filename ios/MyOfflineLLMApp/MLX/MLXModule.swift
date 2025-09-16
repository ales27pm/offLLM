import Foundation
import React

import MLXLLM
import MLXLMCommon

@objc(MLXModule)
@MainActor
final class MLXModule: NSObject {

  // MARK: - RN module wiring
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // MARK: - State
  private var container: ModelContainer?
  private var session: ChatSession?

  // Prefer a light model first for CI/device sanity checks
  private let fallbackModelIDs: [String] = [
    "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "openaccess-ai-collective/tiny-mistral"
  ]

  // MARK: - Helpers

  private static func loadContainer(modelID: String) async throws -> ModelContainer {
    let configuration = ModelConfiguration(id: modelID)
    return try await LLMModelFactory.shared.loadContainer(configuration: configuration)
  }

  private func makeError(_ code: String, _ message: String, underlying: Error? = nil) -> NSError {
    var info: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let underlying { info[NSUnderlyingErrorKey] = underlying }
    return NSError(domain: "MLX", code: 1, userInfo: info)
  }

  private func setActive(container: ModelContainer) {
    self.container = container
    self.session = ChatSession(container)
  }

  private func clearActive() {
    session = nil
    container = nil
  }

  private func idsToTry(from requested: String?) -> [String] {
    var ids: [String] = []
    if let trimmed = requested?.trimmingCharacters(in: .whitespacesAndNewlines),
       !trimmed.isEmpty {
      ids.append(trimmed)
    }
    ids.append(contentsOf: fallbackModelIDs)
    return ids
  }

  // MARK: - React Methods (Promises)

  /// Load a model by HF ID. Falls back to tiny models if the requested one fails.
  /// JS: MLXModule.load(modelId: string | undefined): Promise<boolean>
  @objc(load:resolver:rejecter:)
  func load(_ modelID: String?,
            resolver resolve: @escaping RCTPromiseResolveBlock,
            rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task(priority: .userInitiated) { @MainActor [weak self] in
      guard let self else { return }

      let ids = self.idsToTry(from: modelID)
      var lastError: Error?

      for id in ids {
        do {
          let model = try await Self.loadContainer(modelID: id)
          self.setActive(container: model)
          resolve(true)
          return
        } catch {
          lastError = error
        }
      }

      let triedMessage = "Failed to load any model. Tried: \(ids.joined(separator: ", "))"
      let finalError = lastError ?? self.makeError("MLX_LOAD_ERR", triedMessage)
      reject("MLX_LOAD_ERR", triedMessage, finalError)
    }
  }

  /// Check if a model is loaded.
  /// JS: MLXModule.isLoaded(): Promise<boolean>
  @objc(isLoaded:rejecter:)
  func isLoaded(_ resolve: @escaping RCTPromiseResolveBlock,
                rejecter _: @escaping RCTPromiseRejectBlock) {
    resolve(container != nil)
  }

  /// Generate a response for `prompt` using the current multi-turn session.
  /// JS: MLXModule.generate(prompt: string): Promise<string>
  @objc(generate:resolver:rejecter:)
  func generate(_ prompt: String,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task(priority: .userInitiated) { @MainActor [weak self] in
      guard let self else { return }

      guard let session = self.session else {
        let error = self.makeError("MLX_GEN_ERR", "No model loaded")
        reject("MLX_GEN_ERR", error.localizedDescription, error)
        return
      }

      do {
        let reply = try await session.respond(to: prompt)
        resolve(reply)
      } catch {
        let message = "Generation failed: \(error.localizedDescription)"
        reject("MLX_GEN_ERR", message, error)
      }
    }
  }

  /// Reset the multi-turn chat context (keeps the loaded model).
  /// JS: MLXModule.reset(): void
  @objc(reset)
  func reset() {
    if let container {
      session = ChatSession(container)
    }
  }

  /// Unload the model and clear session.
  /// JS: MLXModule.unload(): void
  @objc(unload)
  func unload() {
    clearActive()
  }
}
