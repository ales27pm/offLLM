import Foundation
import React

import MLXLLM
import MLXLMCommon

@objc(MLXModule)
final class MLXModule: NSObject {

  // MARK: - RN module wiring
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // MARK: - State
  private let workerQueue = DispatchQueue(label: "com.offllm.mlxmodule", qos: .userInitiated)
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

  private func resolveOnMain(_ resolve: @escaping RCTPromiseResolveBlock, value: Any?) {
    DispatchQueue.main.async {
      resolve(value)
    }
  }

  private func rejectOnMain(_ reject: @escaping RCTPromiseRejectBlock,
                            code: String,
                            message: String,
                            error: Error?) {
    let finalError = error ?? makeError(code, message)
    let finalMessage = message.isEmpty ? finalError.localizedDescription : message
    DispatchQueue.main.async {
      reject(code, finalMessage, finalError)
    }
  }

  private func setActiveLocked(container: ModelContainer) {
    self.container = container
    self.session = ChatSession(container)
  }

  private func clearActiveLocked() {
    self.session = nil
    self.container = nil
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

    workerQueue.async { [weak self] in
      guard let self else { return }

      let ids = self.idsToTry(from: modelID)
      var loadedModel: ModelContainer?
      var lastError: Error?

      for id in ids {
        var result: ModelContainer?
        var errorResult: Error?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
          do {
            result = try await Self.loadContainer(modelID: id)
          } catch {
            errorResult = error
          }
          semaphore.signal()
        }

        semaphore.wait()

        if let container = result {
          loadedModel = container
          break
        }

        lastError = errorResult
      }

      guard let container = loadedModel else {
        let message = "Failed to load any model. Tried: \(ids.joined(separator: ", "))"
        self.rejectOnMain(reject,
                          code: "MLX_LOAD_ERR",
                          message: message,
                          error: lastError)
        return
      }

      self.setActiveLocked(container: container)
      self.resolveOnMain(resolve, value: true)
    }
  }

  /// Check if a model is loaded.
  /// JS: MLXModule.isLoaded(): Promise<boolean>
  @objc(isLoaded:rejecter:)
  func isLoaded(_ resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {
    let loaded = workerQueue.sync { self.container != nil }
    resolveOnMain(resolve, value: loaded)
  }

  /// Generate a response for `prompt` using the current multi-turn session.
  /// JS: MLXModule.generate(prompt: string): Promise<string>
  @objc(generate:resolver:rejecter:)
  func generate(_ prompt: String,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {

    workerQueue.async { [weak self] in
      guard let self else { return }

      guard let session = self.session else {
        self.rejectOnMain(reject,
                          code: "MLX_GEN_ERR",
                          message: "No model loaded",
                          error: nil)
        return
      }

      var responseText: String?
      var responseError: Error?
      let semaphore = DispatchSemaphore(value: 0)

      Task {
        do {
          responseText = try await session.respond(to: prompt)
        } catch {
          responseError = error
        }
        semaphore.signal()
      }

      semaphore.wait()

      if let reply = responseText {
        self.resolveOnMain(resolve, value: reply)
      } else {
        let err = responseError ?? self.makeError("MLX_GEN_ERR", "Unknown generation error")
        let message = "Generation failed: \(err.localizedDescription)"
        self.rejectOnMain(reject,
                          code: "MLX_GEN_ERR",
                          message: message,
                          error: err)
      }
    }
  }

  /// Reset the multi-turn chat context (keeps the loaded model).
  /// JS: MLXModule.reset(): void
  @objc(reset)
  func reset() {
    workerQueue.async { [weak self] in
      guard let self else { return }
      if let container = self.container {
        self.session = ChatSession(container)
      }
    }
  }

  /// Unload the model and clear session.
  /// JS: MLXModule.unload(): void
  @objc(unload)
  func unload() {
    workerQueue.async { [weak self] in
      guard let self else { return }
      self.clearActiveLocked()
    }
  }
}
