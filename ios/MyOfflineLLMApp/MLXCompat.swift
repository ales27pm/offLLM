import Foundation
#if canImport(MLXLLM)
import MLXLLM
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

// Bridge newer naming used in your code to released tags:
// Released 2.25.x exposes GenerateParameters. Alias it so your call-sites keep using GenerationOptions.
public typealias GenerationOptions = GenerateParameters

// Minimal facade for "ChatModelLoader" against released MLXLLM.
public enum ChatModelLoader {
    public static func loadModel(
        id: String,
        preferQuantized: Bool = true
    ) async throws -> LanguageModel {
        return try await _fallbackLoad(id: id, preferQuantized: preferQuantized)
    }
    private static func _fallbackLoad(id: String, preferQuantized: Bool) async throws -> LanguageModel {
        #if canImport(MLXLLM)
        if let cfg = MLXLLM.ModelRegistry.named[id] ?? MLXLLM.ModelRegistry.lookup(id: id) {
            return try await MLXLLM.LanguageModel(modelConfiguration: cfg)
        }
        #endif
        throw NSError(domain: "MLXCompat.ChatModelLoader",
                      code: -1001,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to resolve model \(id)."])
    }
}

public extension GenerationOptions {
    init(temperature: Float = 0.7,
         topP: Float = 0.95,
         maxTokens: Int = 512,
         presencePenalty: Float = 0.0,
         frequencyPenalty: Float = 0.0) {
        self.init()
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }
}

