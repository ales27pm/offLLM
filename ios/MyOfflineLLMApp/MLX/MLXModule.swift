//
//  MLXModule.swift
//  monGARS
//
//  React Native bridge for on-device multi-turn chat using MLX.
//
//  IMPORTANT: This uses the ModelContainer API (correct for newer MLX):
//     let container = try await LLMModelFactory.shared.loadContainer(configuration: ...)
//

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
  // The MLX container actor that owns the model + tokenizer + context
  private var container: ModelContainer?
  // Stateful multi-turn chat session bound to the container
  private var session: ChatSession?

  // Prefer a light model first for CI/device sanity checks
  // (You can reorder/add IDs as you like)
  private let fallbackModelIDs: [String] = [
    "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "openaccess-ai-collective/tiny-mistral"
  ]

  // MARK: - Helpers

  private func loadContainer(for modelID: String) async throws -> ModelContainer {
    let cfg = ModelConfiguration(id: modelID)
    // This returns a ModelContainer actor (what ChatSession expects)
    return try await LLMModelFactory.shared.loadContainer(configuration: cfg)
  }

  private func setActive(container: ModelContainer) {
    self.container = container
    self.session = ChatSession(container)
  }

  private func clearActive() {
    self.session = nil
    self.container = nil
  }

  private func makeError(_ code: String, _ message: String, _ underlying: Error? = nil) -> NSError {
    var info: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let underlying { info[NSUnderlyingErrorKey] = underlying }
    return NSError(domain: "MLX", code: 1, userInfo: info)
  }

  // MARK: - React Methods (Promises)

  /// Load a model by HF ID. Falls back to tiny models if the requested one fails.
  /// JS: MLXModule.load(modelId: string | undefined): Promise<boolean>
  @objc(load:resolver:rejecter:)
  func load(_ modelID: String?,
            resolver resolve: @escaping RCTPromiseResolveBlock,
            rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      var tried = [String]()
      var lastErr: Error?

      // Build the try list (requested first, then fallbacks)
      var idsToTry: [String] = []
      if let id = modelID?.trimmingCharacters(in: .whitespacesAndNewlines),
         !id.isEmpty { idsToTry.append(id) }
      idsToTry.append(contentsOf: self.fallbackModelIDs)

      for id in idsToTry {
        tried.append(id)
        do {
          let c = try await self.loadContainer(for: id)
          self.setActive(container: c)
          resolve(true)
          return
        } catch {
          lastErr = error
          // Try next candidate
        }
      }

      reject("MLX_LOAD_ERR",
             "Failed to load any model. Tried: \(tried.joined(separator: ", "))",
             lastErr ?? self.makeError("MLX_LOAD_ERR", "Unknown load error"))
    }
  }

  /// Check if a model is loaded.
  /// JS: MLXModule.isLoaded(): Promise<boolean>
  @objc(isLoaded:rejecter:)
  func isLoaded(_ resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(self.container != nil)
  }

  /// Generate a response for `prompt` using the current multi-turn session.
  /// JS: MLXModule.generate(prompt: string): Promise<string>
  @objc(generate:resolver:rejecter:)
  func generate(_ prompt: String,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      guard let session = self.session else {
        reject("MLX_GEN_ERR", "No model loaded", self.makeError("MLX_GEN_ERR", "No model loaded"))
        return
      }

      do {
        // Simple one-shot completion that *extends* the conversation internally.
        let reply = try await session.respond(to: prompt)
        resolve(reply)
      } catch {
        reject("MLX_GEN_ERR", "Generation failed: \(error.localizedDescription)", error)
      }
    }
  }

  /// Reset the multi-turn chat context (keeps the loaded model).
  /// JS: MLXModule.reset(): void
  @objc(reset)
  func reset() {
    if let container = self.container {
      self.session = ChatSession(container)
    }
  }

  /// Unload the model and clear session.
  /// JS: MLXModule.unload(): void
  @objc(unload)
  func unload() {
    clearActive()
  }
}
