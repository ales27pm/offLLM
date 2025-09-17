import Foundation
import React

import MLXLLM
import MLXLMCommon

extension ChatSession: @unchecked Sendable {}

private actor ChatSessionActor {
  private struct Waiter {
    let id: UUID
    let continuation: CheckedContinuation<Void, Error>
  }

  private let session: ChatSession
  private var isResponding = false
  private var waitQueue: [Waiter] = []

  init(session: ChatSession) {
    self.session = session
  }

  func respond(to prompt: String) async throws -> String {
    try Task.checkCancellation()

    if isResponding {
      try await waitTurn()
    }

    isResponding = true
    defer { resumeNextWaiter() }

    try Task.checkCancellation()
    return try await MainActor.run {
      try await session.respond(to: prompt)
    }
  }

  private func waitTurn() async throws {
    let waiterID = UUID()

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        waitQueue.append(Waiter(id: waiterID, continuation: continuation))
      }
    } onCancel: {
      Task { await self.cancelWaiter(id: waiterID) }
    }
  }

  private func resumeNextWaiter() {
    guard !waitQueue.isEmpty else {
      isResponding = false
      return
    }

    let next = waitQueue.removeFirst()
    next.continuation.resume(returning: ())
  }

  private func cancelWaiter(id: UUID) {
    guard let index = waitQueue.firstIndex(where: { $0.id == id }) else { return }
    let waiter = waitQueue.remove(at: index)
    waiter.continuation.resume(throwing: CancellationError())
  }
}

@MainActor
private final class PromiseCallbacks {
  private let resolve: RCTPromiseResolveBlock
  private let reject: RCTPromiseRejectBlock

  init(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    self.resolve = resolve
    self.reject = reject
  }

  func fulfill(_ value: Any?) {
    resolve(value)
  }

  func fail(code: String, message: String, error: Error?) {
    reject(code, message, error)
  }
}

@objc(MLXModule)
@MainActor
final class MLXModule: NSObject {

  // MARK: - RN module wiring
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // MARK: - State
  private enum SessionAccessError: Error {
    case noActiveSession
  }

  private var container: ModelContainer?
  private var sessionActor: ChatSessionActor?

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

  private static func makeError(_ code: String, _ message: String, underlying: Error? = nil) -> NSError {
    var info: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let underlying { info[NSUnderlyingErrorKey] = underlying }
    return NSError(domain: "MLX", code: 1, userInfo: info)
  }

  private func setActive(container: ModelContainer) {
    self.container = container
    self.sessionActor = ChatSessionActor(session: ChatSession(container))
  }

  private func clearActive() {
    sessionActor = nil
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

    let callbacks = PromiseCallbacks(resolve: resolve, reject: reject)

    Task(priority: .userInitiated) { @MainActor [weak self] in
      guard let self else { return }

      let ids = self.idsToTry(from: modelID)
      var lastError: Error?

      for id in ids {
        do {
          let model = try await Self.loadContainer(modelID: id)
          self.setActive(container: model)
          callbacks.fulfill(true)
          return
        } catch {
          lastError = error
        }
      }

      let triedMessage = "Failed to load any model. Tried: \(ids.joined(separator: ", "))"
      let finalError = lastError ?? Self.makeError("MLX_LOAD_ERR", triedMessage, underlying: lastError)
      callbacks.fail(code: "MLX_LOAD_ERR", message: triedMessage, error: finalError)
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

    let callbacks = PromiseCallbacks(resolve: resolve, reject: reject)

    Task(priority: .userInitiated) { @MainActor [weak self] in
      guard let self else { return }

      do {
        let reply = try await self.respondUsingActiveSession(to: prompt)
        callbacks.fulfill(reply)
      } catch SessionAccessError.noActiveSession {
        let error = Self.makeError("MLX_GEN_ERR", "No model loaded")
        callbacks.fail(code: "MLX_GEN_ERR", message: error.localizedDescription, error: error)
      } catch {
        let message = "Generation failed: \(error.localizedDescription)"
        callbacks.fail(code: "MLX_GEN_ERR", message: message, error: error)
      }
    }
  }

  @MainActor
  private func respondUsingActiveSession(to prompt: String) async throws -> String {
    guard let sessionActor else {
      throw SessionAccessError.noActiveSession
    }

    return try await sessionActor.respond(to: prompt)
  }

  /// Reset the multi-turn chat context (keeps the loaded model).
  /// JS: MLXModule.reset(): void
  @objc(reset)
  func reset() {
    if let container {
      sessionActor = ChatSessionActor(session: ChatSession(container))
    }
  }

  /// Unload the model and clear session.
  /// JS: MLXModule.unload(): void
  @objc(unload)
  func unload() {
    clearActive()
  }
}
