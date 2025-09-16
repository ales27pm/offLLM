import Foundation
import React
import MLX
import MLXLLM
import MLXLMCommon

@objc(MLXModule)
final class MLXModule: NSObject {

  // React Native module name and setup
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // State
  private var modelContainer: ModelContainer?
  private var chatSession: ChatSession?

  // Fallback model IDs
  private let fallbackModelIDs = [
    "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "openaccess-ai-collective/tiny-mistral"
  ]

  // MARK: - React Methods

  @objc(loadModel:resolver:rejecter:)
  func loadModel(_ modelID: String,
                 resolver resolve: @escaping RCTPromiseResolveBlock,
                 rejecter reject: @escaping RCTPromiseRejectBlock) {

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      // Determine IDs to try: user-specified, then fallbacks
      var idsToTry = [String]()
      if !modelID.trimmingCharacters(in: .whitespaces).isEmpty {
        idsToTry.append(modelID)
      }
      idsToTry.append(contentsOf: self.fallbackModelIDs)

      var loadedModel: ModelContainer? = nil
      var lastError: Error?

      // Attempt to load each model ID
      for id in idsToTry {
        var result: ModelContainer?
        var errorResult: Error?
        let sem = DispatchSemaphore(value: 0)

        Task {
          do {
            result = try await MLXLMCommon.loadModelContainer(id: id)
          } catch {
            errorResult = error
          }
          sem.signal()
        }
        sem.wait()

        if let model = result {
          loadedModel = model
          break
        }
        lastError = errorResult
      }

      // If none loaded, reject the promise
      if loadedModel == nil {
        DispatchQueue.main.async {
          let err = lastError ?? NSError(domain: "MLX", code: 1,
                   userInfo: [NSLocalizedDescriptionKey: "Failed to load any model."])
          reject("MLX_LOAD_ERR", "Model loading failed: \(err.localizedDescription)", err)
        }
        return
      }

      // Keep references and resolve promise
      self.modelContainer = loadedModel
      self.chatSession = ChatSession(loadedModel!)
      DispatchQueue.main.async {
        resolve(true)
      }
    }
  }

  @objc(unloadModel)
  func unloadModel() {
    self.chatSession = nil
    self.modelContainer = nil
  }

  @objc(generate:resolver:rejecter:)
  func generate(_ prompt: String,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      // Ensure a model is loaded
      guard let session = self.chatSession else {
        DispatchQueue.main.async {
          let err = NSError(domain: "MLX", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "No model loaded"])
          reject("MLX_GEN_ERR", "Generation failed: \(err.localizedDescription)", err)
        }
        return
      }

      // Run generation asynchronously and wait
      var responseText: String?
      var responseError: Error?
      let sem = DispatchSemaphore(value: 0)

      Task {
        do {
          responseText = try await session.respond(to: prompt)
        } catch {
          responseError = error
        }
        sem.signal()
      }
      sem.wait()

      // Resolve or reject based on result
      if let response = responseText {
        DispatchQueue.main.async {
          resolve(response)
        }
      } else {
        DispatchQueue.main.async {
          let err = responseError ?? NSError(domain: "MLX", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
          reject("MLX_GEN_ERR", "Generation failed: \(err.localizedDescription)", err)
        }
      }
    }
  }

  @objc(resetChat)
  func resetChat() {
    if let modelContainer = self.modelContainer {
      self.chatSession = ChatSession(modelContainer)
    }
  }
}

extension MLXModule: RCTBridgeModule {}
