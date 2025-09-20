//
//  MLXModule.swift
//  monGARS
//
//  Swift 6-safe RN bridge that streams tokens via MLXEvents.
//

import Foundation
import React

@preconcurrency import MLXLLM
@preconcurrency import MLXLMCommon

// MARK: - Main-actor session owner that serializes ChatSession access
@MainActor
private final class ChatSessionActor {
  private var container: ModelContainer
  private var isResponding = false
  private var shouldStop = false

  init(container: ModelContainer) {
    self.container = container
  }

  func reset() {
    isResponding = false
    shouldStop = false
  }

  func stop() {
    shouldStop = true
  }

  func generateOnce(prompt: String, topK: Int, temperature: Float) async throws -> String {
    guard !isResponding else { return "" }
    isResponding = true
    defer { isResponding = false; shouldStop = false }

    var out = ""
    let session = ChatSession(container, generateParameters: makeParameters(topK: topK, temperature: temperature))
    for try await token in session.streamResponse(to: prompt) {
      if shouldStop { break }
      out.append(token)
    }
    return out
  }

  func stream(prompt: String, topK: Int, temperature: Float, onToken: @escaping @Sendable (String) -> Void) async throws {
    guard !isResponding else { return }
    isResponding = true
    defer { isResponding = false; shouldStop = false }

    let session = ChatSession(container, generateParameters: makeParameters(topK: topK, temperature: temperature))
    for try await token in session.streamResponse(to: prompt) {
      if shouldStop { break }
      onToken(token)
    }
  }

  private func makeParameters(topK: Int, temperature: Float) -> GenerateParameters {
    var parameters = GenerateParameters()
    parameters.temperature = temperature
    parameters.topP = topPValue(for: topK)
    return parameters
  }

  private func topPValue(for topK: Int) -> Float {
    guard topK > 0 else { return 0.99 }
    let normalized = min(max(Float(topK), 1), 400)
    let baseline: Float = 40
    let mapped = normalized / baseline
    return max(0.1, min(mapped, 0.99))
  }
}

// MARK: - Promise wrapper for RN
final class MLXPromise {
  let resolve: RCTPromiseResolveBlock
  let reject: RCTPromiseRejectBlock
  init(_ r: @escaping RCTPromiseResolveBlock, _ j: @escaping RCTPromiseRejectBlock) { resolve = r; reject = j }
  func ok(_ v: Any?) { resolve(v) }
  func fail(_ code: String, _ msg: String, _ err: Error? = nil) { reject(code, msg, err) }
}

// MARK: - RN Module
@objc(MLXModule)
@MainActor
final class MLXModule: NSObject {

  // RN wiring
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // State
  private var container: ModelContainer?
  private var actor: ChatSessionActor?

  private let fallbacks: [String] = [
    "mlx-community/gemma-2-2b-it",
    "mlx-community/llama-3.1-instruct-8b",
    "mlx-community/phi-3-mini-4k-instruct",
    "openaccess-ai-collective/tiny-mistral"
  ]

  // Helpers
  private static func loadContainer(modelID: String) async throws -> ModelContainer {
    let cfg = ModelConfiguration(id: modelID)
    return try await LLMModelFactory.shared.loadContainer(configuration: cfg)
  }

  private func setActive(container: ModelContainer) {
    self.container = container
    self.actor = ChatSessionActor(container: container)
  }

  private func idsToTry(from requested: String?) -> [String] {
    var ids: [String] = []
    if let trimmed = requested?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
      ids.append(trimmed)
    }
    ids.append(contentsOf: fallbacks)
    return ids
  }

  // MARK: - JS API

  /// JS: MLXModule.load(modelID?: string): Promise<{id: string}>
  @objc(load:resolver:rejecter:)
  func load(modelID: NSString?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let p = MLXPromise(resolve, reject)
    let requestedID = modelID as String?
    let candidateIDs = idsToTry(from: requestedID)
    Task { [weak self, candidateIDs] in
      guard let self else { return }
      var lastError: Error?
      for id in candidateIDs {
        do {
          let container = try await Self.loadContainer(modelID: id)
          await MainActor.run { self.setActive(container: container) }
          p.ok(["id": id])
          return
        } catch {
          lastError = error
        }
      }
      if let lastError {
        p.fail("ENOENT", "Failed to load any model id", lastError)
      } else {
        p.fail("ENOENT", "Failed to load any model id")
      }
    }
  }

  /// JS: MLXModule.reset(): void
  @objc(reset)
  func reset() {
    guard let activeActor = actor else { return }
    Task {
      await activeActor.reset()
    }
  }

  /// JS: MLXModule.unload(): void
  @objc(unload)
  func unload() {
    self.container = nil
    self.actor = nil
  }

  /// JS: MLXModule.stop(): void
  @objc(stop)
  func stop() {
    let activeActor = actor
    Task {
      await activeActor?.stop()
      await MainActor.run { MLXEvents.shared?.emitStopped() }
    }
  }

  /// JS: MLXModule.generate(prompt: string, opts?: {topK?: number, temperature?: number}): Promise<string>
  @objc(generate:options:resolver:rejecter:)
  func generate(prompt: NSString,
                options: NSDictionary?,
                resolve: @escaping RCTPromiseResolveBlock,
                reject: @escaping RCTPromiseRejectBlock) {
    let p = MLXPromise(resolve, reject)
    let topK = (options?["topK"] as? NSNumber)?.intValue ?? 40
    let temperature = (options?["temperature"] as? NSNumber)?.floatValue ?? 0.7
    let promptString = prompt as String

    guard let activeActor = actor else {
      p.fail("ENOSESSION", "No active session")
      return
    }

    Task {
      do {
        let text = try await activeActor.generateOnce(prompt: promptString, topK: topK, temperature: temperature)
        p.ok(text)
      } catch {
        p.fail("EGEN", "Generation failed", error)
      }
    }
  }

  /// JS: MLXModule.startStream(prompt: string, opts?: {topK?: number, temperature?: number}): Promise<void>
  @objc(startStream:options:resolver:rejecter:)
  func startStream(prompt: NSString,
                   options: NSDictionary?,
                   resolve: @escaping RCTPromiseResolveBlock,
                   reject: @escaping RCTPromiseRejectBlock) {
    let p = MLXPromise(resolve, reject)
    let topK = (options?["topK"] as? NSNumber)?.intValue ?? 40
    let temperature = (options?["temperature"] as? NSNumber)?.floatValue ?? 0.7
    let promptString = prompt as String

    guard let activeActor = actor else {
      p.fail("ENOSESSION", "No active session")
      return
    }

    // Non-detached Task reduces unnecessary Sendable requirements
    // and avoids data-race diagnostics under Swift 6.
    Task {
      do {
        try await activeActor.stream(prompt: promptString, topK: topK, temperature: temperature) { token in
          Task { @MainActor in MLXEvents.shared?.emitToken(token) }
        }
        Task { @MainActor in MLXEvents.shared?.emitCompleted() }
        p.ok(nil)
      } catch {
        Task { @MainActor in MLXEvents.shared?.emitError("ESTREAM", message: "Stream failed") }
        p.fail("ESTREAM", "Stream failed", error)
      }
    }
  }
}
