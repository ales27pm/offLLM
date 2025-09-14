import Foundation
#if canImport(MLXLLM)
import MLXLLM
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

public enum MLXCompat {

    // MARK: Generation options bridge
    #if canImport(MLXLMCommon)
    public typealias GenerationOptions = GenerateParameters
    #else
    public struct GenerationOptions {
        public var temperature: Float = 0.7
        public var topP: Float = 0.95
        public var maxTokens: Int = 512
        public var presencePenalty: Float = 0.0
        public var frequencyPenalty: Float = 0.0
        public init() {}
        public init(temperature: Float = 0.7, topP: Float = 0.95, maxTokens: Int = 512,
                    presencePenalty: Float = 0.0, frequencyPenalty: Float = 0.0) {
            self.temperature = temperature
            self.topP = topP
            self.maxTokens = maxTokens
            self.presencePenalty = presencePenalty
            self.frequencyPenalty = frequencyPenalty
        }
    }
    #endif

    public static func makeOptions(temperature: Float = 0.7,
                                   topP: Float = 0.95,
                                   maxTokens: Int = 512,
                                   presencePenalty: Float = 0.0,
                                   frequencyPenalty: Float = 0.0) -> GenerationOptions {
        var g = GenerationOptions()
        g.temperature = temperature
        g.topP = topP
        g.maxTokens = maxTokens
        g.presencePenalty = presencePenalty
        g.frequencyPenalty = frequencyPenalty
        return g
    }

    // MARK: Loader facade
    public struct ModelLoader {
        public let idOrPath: String
        public init(modelURL: URL) {
            self.idOrPath = modelURL.isFileURL ? modelURL.path : modelURL.absoluteString
        }
        public init(modelId: String) { self.idOrPath = modelId }
    }

    // MARK: Chat session facade
    public final class ChatSession {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        private let model: LanguageModel
        #endif

        public init(loader: ModelLoader) throws {
            #if canImport(MLXLLM) && canImport(MLXLMCommon)
            if let cfg = MLXLLM.ModelRegistry.named[loader.idOrPath]
                ?? MLXLLM.ModelRegistry.lookup(id: loader.idOrPath) {
                self.model = try awaitOrThrowSync {
                    try await MLXLLM.LanguageModel(modelConfiguration: cfg)
                }
                return
            }
            if FileManager.default.fileExists(atPath: loader.idOrPath),
               let cfg = MLXLLM.ModelRegistry.lookup(path: loader.idOrPath) {
                self.model = try awaitOrThrowSync {
                    try await MLXLLM.LanguageModel(modelConfiguration: cfg)
                }
                return
            }
            throw NSError(domain: "MLXCompat.ChatSession", code: -1002,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Could not resolve model '\(loader.idOrPath)'."])
            #else
            throw NSError(domain: "MLXCompat.ChatSession", code: -1000,
                          userInfo: [NSLocalizedDescriptionKey:
                            "MLX libraries not available in this build."])
            #endif
        }

        public func generate(_ prompt: String, options: GenerationOptions) async throws -> String {
            #if canImport(MLXLLM) && canImport(MLXLMCommon)
            return try await model.generate(prompt: prompt, parameters: options)
            #else
            throw NSError(domain: "MLXCompat.ChatSession", code: -1001,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Generation not supported without MLX libraries."])
            #endif
        }
    }
}

@discardableResult
private func awaitOrThrowSync<T>(_ op: @escaping () async throws -> T) throws -> T {
    var result: Result<T, Error>?
    let sem = DispatchSemaphore(value: 0)
    Task {
        do { result = .success(try await op()) }
        catch { result = .failure(error) }
        sem.signal()
    }
    sem.wait()
    return try result!.get()
}

