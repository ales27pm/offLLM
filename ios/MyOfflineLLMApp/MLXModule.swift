// MLXModule.swift
// React Native bridge for on-device multi-turn chat generation using MLX (MLXLLM, MLXLMCommon).
//
// Supports fallback to lightweight models for initial local validation.
//
// Usage:
//   - loadModel(modelID): Loads the specified model from Hugging Face. If loading fails, tries fallback models.
//   - generate(prompt): Generates a chat response for the given prompt (multi-turn conversation).
//   - resetChat(): Resets the conversation context.
//   - unloadModel(): Unloads the model to free memory.
import Foundation
import React
import MLX
import MLXLLM
import MLXLMCommon

@objc(MLXModule)
final class MLXModule: NSObject {

  // MARK: - React Native Module Setup
  @objc static func moduleName() -> String! { "MLXModule" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  // MARK: - State
  private var modelContainer: ModelContainer?
  private var chatSession: ChatSession?

  // Fallback-compatible lightweight model IDs for initial validation
  private let fallbackModelIDs = [
    "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "openaccess-ai-collective/tiny-mistral"
  ]

  // MARK: - React Methods

  /// Load a model given its Hugging Face ID. If loading the specified model fails,
  /// attempts to load fallback lightweight models.
  @objc(loadModel:resolver:rejecter:)
  func loadModel(_ modelID: String,
                 resolver resolve: @escaping RCTPromiseResolveBlock,
                 rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task(priority: .userInitiated) { [weak self] in
      guard let self = self else { return }
      do {
        // Determine which IDs to try (user-specified, then fallback)
        var idsToTry = [String]()
        if !modelID.trimmingCharacters(in: .whitespaces).isEmpty {
          idsToTry.append(modelID)
        }
        idsToTry.append(contentsOf: fallbackModelIDs)

        var loadedModel: ModelContainer? = nil
        var lastError: Error?

        // Attempt to load each model ID until one succeeds
        for id in idsToTry {
          do {
            // Load model from Hugging Face using MLXLMCommon
            loadedModel = try await MLXLMCommon.loadModel(id: id)
            break
          } catch {
            lastError = error
            // try next ID
          }
        }

        // If none loaded successfully, throw the last error
        guard let modelContainer = loadedModel else {
          throw lastError ?? NSError(domain: "MLX", code: 1,
                   userInfo: [NSLocalizedDescriptionKey: "Failed to load any model."])
        }

        // Keep reference to the loaded model
        self.modelContainer = modelContainer
        // Create a new chat session (multi-turn conversation)
        self.chatSession = ChatSession(modelContainer)

        resolve(true)
      } catch {
        reject("MLX_LOAD_ERR", "Model loading failed: \(error.localizedDescription)", error)
      }
    }
  }

  /// Unload the current model to free memory.
  @objc(unloadModel)
  func unloadModel() {
    self.chatSession = nil
    self.modelContainer = nil
  }

  /// Generate a chat response to the given prompt. Uses the current conversation context.
  @objc(generate:resolver:rejecter:)
  func generate(_ prompt: String,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {

    Task(priority: .userInitiated) { [weak self] in
      guard let self = self else { return }
      do {
        // Ensure model is loaded
        guard let session = self.chatSession else {
          throw NSError(domain: "MLX", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No model loaded"])
        }
        // Generate response for the prompt
        let response = try await session.respond(to: prompt)
        resolve(response)
      } catch {
        reject("MLX_GEN_ERR", "Generation failed: \(error.localizedDescription)", error)
      }
    }
  }

  /// Reset the conversation context (start a new chat session with the loaded model).
  @objc(resetChat)
  func resetChat() {
    if let modelContainer = self.modelContainer {
      self.chatSession = ChatSession(modelContainer)
    }
  }
}

extension MLXModule: RCTBridgeModule {}
