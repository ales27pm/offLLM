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

// MARK: - Actor that owns ChatSession (off-main, concurrency-safe)
private actor ChatSessionActor {
  private var session: ChatSession
  private var isResponding = false
  private var shouldStop = false

  init(container: ModelContainer) {
    self.session = ChatSession(container)
  }

  func reset(with container: ModelContainer? = nil) {
    if let c = container {
      self.session = ChatSession(c)
    } else {
      self.session = ChatSession(self.session.container)
    }
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
    let req = makeRequest(prompt: prompt, topK: topK, temperature: temperature)
    for try await token in try session.generate(request: req) {
      if shouldStop { break }
      out.append(token)
    }
    return out
  }

  func stream(prompt: String, topK: Int, temperature: Float, onToken: @escaping (String) -> Void) async throws {
    guard !isResponding else { return }
    isResponding = true
    defer { isResponding = false; shouldStop = false }

    let req = makeRequest(prompt: prompt, topK: topK, temperature: temperature)
    for try await token in try session.generate(request: req) {
      if shouldStop { break }
      onToken(token)
    }
  }

  private func makeRequest(prompt: String, topK: Int, temperature: Float) -> GenerateRequest {
    let params = GenerateRequest.Parameters(topK: topK, temperature: temperature)
    return GenerateRequest(text: prompt, parameters: params)
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
    Task.detached { [weak self] in
      guard let self else { return }
      do {
        let candidateIDs = await MainActor.run { self.idsToTry(from: modelID as String?) }
        for id in candidateIDs {
          do {
            let c = try await Self.loadContainer(modelID: id)
            await MainActor.run { self.setActive(container: c) }
            p.ok(["id": id])
            return
          } catch {
            // try next id
          }
        }
        p.fail("ENOENT", "Failed to load any model id")
      } catch {
        p.fail("ELOAD", "Load failed", error)
      }
    }
  }

  /// JS: MLXModule.reset(): void
  @objc(reset)
  func reset() {
    if let c = container {
      Task { [weak self] in
        await self?.actor?.reset(with: c)
      }
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
    Task { [weak self] in
      await self?.actor?.stop()
      await MLXEvents.shared?.emitStopped()
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

    Task.detached { [weak self] in
      guard let self else { return }
      guard let actor = await self.actor else {
        p.fail("ENOSESSION", "No active session")
        return
      }
      do {
        let text = try await actor.generateOnce(prompt: prompt as String, topK: topK, temperature: temperature)
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

    Task.detached { [weak self] in
      guard let self else { return }
      guard let actor = await self.actor else { p.fail("ENOSESSION", "No active session"); return }
      do {
        try await actor.stream(prompt: prompt as String, topK: topK, temperature: temperature) { token in
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
