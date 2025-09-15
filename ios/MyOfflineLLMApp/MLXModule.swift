import Foundation
import React
import MLX
import MLXLLM
import MLXLMCommon

@objc(MLXModule)
final class MLXModule: NSObject, RCTBridgeModule {
  static func moduleName() -> String! { "MLXModule" }
  static func requiresMainQueueSetup() -> Bool { false }

  private let modelStore = ModelStore()
  private let generationManager = GenerationManager()

  // MARK: - React Methods

  @objc(loadModel:options:resolver:rejecter:)
  func loadModel(_ identifier: String,
                 options: [AnyHashable: Any]?,
                 resolver resolve: @escaping RCTPromiseResolveBlock,
                 rejecter reject: @escaping RCTPromiseRejectBlock) {
    Task(priority: .userInitiated) { [weak self] in
      guard let self = self else { return }

      do {
        let request = try self.makeLoadRequest(identifier: identifier, options: options)
        let container = try await loadModelContainer(configuration: request.configuration)

        await self.generationManager.cancelActiveTask()
        await self.modelStore.update(container: container, request: request)

        let payload: [String: Any] = [
          "status": "loaded",
          "model": request.originalIdentifier,
          "source": request.source.rawValue,
          "path": request.resolvedPath,
          "loadedAt": ISO8601DateFormatter().string(from: Date()),
        ]

        DispatchQueue.main.async {
          resolve(payload)
        }
      } catch {
        DispatchQueue.main.async {
          reject("MLX_LOAD_ERROR", "Failed to load model: \(error.localizedDescription)", error)
        }
      }
    }
  }

  @objc(unloadModel:rejecter:)
  func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                   rejecter reject: @escaping RCTPromiseRejectBlock) {
    Task {
      await generationManager.cancelActiveTask()
      await modelStore.unload()
      DispatchQueue.main.async {
        resolve(true)
      }
    }
  }

  @objc(generate:options:resolver:rejecter:)
  func generate(_ prompt: String,
                options: [AnyHashable: Any]?,
                resolver resolve: @escaping RCTPromiseResolveBlock,
                rejecter reject: @escaping RCTPromiseRejectBlock) {
    let requestID = UUID()
    let task = Task(priority: .userInitiated) { [weak self] in
      guard let self = self else { return }
      defer { await self.generationManager.clear(id: requestID) }

      do {
        guard let container = await self.modelStore.currentContainer() else {
          throw MLXModuleError.modelNotLoaded
        }

        let parameters = self.makeGenerateParameters(from: options)
        let session = ChatSession(container, generateParameters: parameters)

        let start = Date()
        var output = ""

        for try await chunk in session.streamResponse(to: prompt) {
          if Task.isCancelled {
            throw CancellationError()
          }
          output += chunk
        }

        if Task.isCancelled {
          throw CancellationError()
        }

        let duration = Date().timeIntervalSince(start)
        let identifier = await self.modelStore.currentIdentifier()
        let tokensGenerated = output.split { $0.isWhitespace }.count

        let payload: [String: Any] = [
          "text": output,
          "duration": duration,
          "model": identifier ?? NSNull(),
          "tokensGenerated": tokensGenerated,
        ]

        DispatchQueue.main.async {
          resolve(payload)
        }
      } catch {
        DispatchQueue.main.async {
          if Task.isCancelled || error is CancellationError {
            reject("MLX_CANCELLED", "Generation cancelled", nil)
          } else {
            reject("MLX_GENERATE_ERROR", "Generation failed: \(error.localizedDescription)", error)
          }
        }
      }
    }

    Task {
      await generationManager.replace(with: task, id: requestID)
    }
  }

  @objc func cancel() {
    Task {
      await generationManager.cancelActiveTask()
    }
  }
}

// MARK: - Helpers

private extension MLXModule {
  struct ModelLoadRequest {
    let configuration: ModelConfiguration
    let originalIdentifier: String
    let resolvedPath: String
    let source: ModelSource
  }

  enum ModelSource: String {
    case directory
    case hub
  }

  enum MLXModuleError: LocalizedError {
    case emptyIdentifier
    case modelNotLoaded

    var errorDescription: String? {
      switch self {
      case .emptyIdentifier:
        return "A model identifier or path must be provided."
      case .modelNotLoaded:
        return "No MLX model has been loaded."
      }
    }
  }

  func makeLoadRequest(identifier: String,
                       options: [AnyHashable: Any]?) throws -> ModelLoadRequest {
    let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw MLXModuleError.emptyIdentifier }

    let expanded = (trimmed as NSString).expandingTildeInPath
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    if fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
      let url = URL(fileURLWithPath: expanded, isDirectory: true)
      return ModelLoadRequest(
        configuration: ModelConfiguration(directory: url),
        originalIdentifier: trimmed,
        resolvedPath: url.path,
        source: .directory
      )
    }

    let revision: String
    if let revisionValue = options?["revision"] as? String, !revisionValue.isEmpty {
      revision = revisionValue
    } else {
      revision = "main"
    }

    return ModelLoadRequest(
      configuration: ModelConfiguration(id: trimmed, revision: revision),
      originalIdentifier: trimmed,
      resolvedPath: trimmed,
      source: .hub
    )
  }

  func makeGenerateParameters(from options: [AnyHashable: Any]?) -> GenerateParameters {
    var maxTokens: Int?
    var temperature: Float = 0.7
    var topP: Float = 1.0
    var repetitionPenalty: Float?
    var repetitionContextSize = 20

    if let options {
      if let number = options["maxTokens"] as? NSNumber {
        let value = number.intValue
        maxTokens = value > 0 ? value : nil
      } else if let value = options["maxTokens"] as? Int, value > 0 {
        maxTokens = value
      }

      if let tempNumber = options["temperature"] as? NSNumber {
        temperature = Float(truncating: tempNumber)
      } else if let tempValue = options["temperature"] as? Double {
        temperature = Float(tempValue)
      }

      if let topPNumber = options["topP"] as? NSNumber {
        topP = max(0.0, min(1.0, Float(truncating: topPNumber)))
      } else if let topPValue = options["topP"] as? Double {
        topP = max(0.0, min(1.0, Float(topPValue)))
      }

      if let penaltyNumber = options["repetitionPenalty"] as? NSNumber {
        repetitionPenalty = Float(truncating: penaltyNumber)
      } else if let penaltyValue = options["repetitionPenalty"] as? Double {
        repetitionPenalty = Float(penaltyValue)
      }

      if let contextNumber = options["repetitionContextSize"] as? NSNumber {
        repetitionContextSize = max(0, contextNumber.intValue)
      } else if let contextValue = options["repetitionContextSize"] as? Int {
        repetitionContextSize = max(0, contextValue)
      }
    }

    var parameters = GenerateParameters(maxTokens: maxTokens)
    parameters.temperature = temperature
    parameters.topP = topP
    parameters.repetitionPenalty = repetitionPenalty
    parameters.repetitionContextSize = repetitionContextSize
    return parameters
  }
}

// MARK: - State Containers

private actor ModelStore {
  private var container: ModelContainer?
  private var identifier: String?
  private var resolvedPath: String?
  private var source: MLXModule.ModelSource?
  private var loadedAt: Date?

  func update(container: ModelContainer, request: MLXModule.ModelLoadRequest) {
    self.container = container
    self.identifier = request.originalIdentifier
    self.resolvedPath = request.resolvedPath
    self.source = request.source
    self.loadedAt = Date()
  }

  func unload() {
    container = nil
    identifier = nil
    resolvedPath = nil
    source = nil
    loadedAt = nil
  }

  func currentContainer() -> ModelContainer? {
    container
  }

  func currentIdentifier() -> String? {
    identifier
  }

  func currentResolvedPath() -> String? {
    resolvedPath
  }

  func currentSource() -> MLXModule.ModelSource? {
    source
  }

  func lastLoadedAt() -> Date? {
    loadedAt
  }
}

private actor GenerationManager {
  private var active: (id: UUID, task: Task<Void, Never>)?

  func replace(with task: Task<Void, Never>, id: UUID) {
    if let current = active {
      current.task.cancel()
    }
    active = (id, task)
  }

  func clear(id: UUID) {
    if active?.id == id {
      active = nil
    }
  }

  func cancelActiveTask() {
    if let current = active {
      current.task.cancel()
      active = nil
    }
  }
}
