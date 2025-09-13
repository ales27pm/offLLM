//
//  MLXCompat.swift
//  Glue layer to compile code written for newer mlx-libraries APIs
//  against released 2.25.x without changing call-sites.
//
//  Safe to keep in-tree; becomes a no-op when upstream adds these types.
//

import Foundation
#if canImport(MLXLLM)
import MLXLLM
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

// MARK: - Typealiases for renamed structs

// Your code uses `GenerationOptions`; 2.25.x exposes `GenerateParameters` in MLXLMCommon.
// Docs show GenerateParameters as the public generation settings type in released builds.
// https://swiftpackageindex.com/ml-explore/mlx-swift-examples/2.25.5/documentation/mlxlmcommon
@available(*, deprecated, message: "Upstream now provides GenerationOptions directly")
public typealias GenerationOptions = GenerateParameters

// MARK: - Minimal ChatModelLoader re-creation (forwarder)
//
// Upstream main may provide a ChatModelLoader; the released 2.25.x doesn’t.
// We create a tiny facade with the shape your code expects, but forward to
// the public loading API that exists in 2.25.x (MLXLLM).
// The example/docs show simple `loadModel(id:)`-style entry points on the LLM side.
// https://github.com/ml-explore/mlx-swift-examples  (see Interacting with LLMs)
// https://swiftpackageindex.com/ml-explore/mlx-swift-examples/2.25.7
//
public enum ChatModelLoader {
    /// Load a chat-capable LanguageModel by model identifier.
    /// - Parameters:
    ///   - id: e.g. "mlx-community/Qwen3-4B-4bit"
    ///   - preferQuantized: if true, favor quantized weights when the registry supports it.
    /// - Returns: a model conforming to the LanguageModel protocol from MLXLMCommon.
    public static func loadModel(
        id: String,
        preferQuantized: Bool = true
    ) async throws -> LanguageModel {
        // For 2.25.x the common pattern is through registry/config helpers.
        // Try the higher-level convenience first; if unavailable, fall back
        // to explicit registry resolution.
        if let loader = _ConvenienceLoader.shared {
            return try await loader(id, preferQuantized)
        }
        return try await _fallbackLoad(id: id, preferQuantized: preferQuantized)
    }

    // MARK: Internal helpers

    private static func _fallbackLoad(
        id: String,
        preferQuantized: Bool
    ) async throws -> LanguageModel {
        // In 2.25.x, models are typically resolved via ModelRegistry,
        // then a LanguageModel is constructed. We account for both LLM & VLM.
        // Importers only pay for what’s present thanks to canImport.
        #if canImport(MLXLLM)
        // Prefer LLM registry if it knows the id; otherwise try a direct open by id.
        if let config = MLXLLM.ModelRegistry.named[id] ?? MLXLLM.ModelRegistry.lookup(id: id) {
            return try await MLXLLM.LanguageModel(modelConfiguration: config)
        }
        // As a pragmatic fallback, attempt a direct loader if provided by the lib.
        if let direct = _DirectLoader.llm {
            return try await direct(id, preferQuantized)
        }
        #endif

        // If you also support VLMs, add a similar branch here with MLXVLM.

        throw NSError(
            domain: "MLXCompat.ChatModelLoader",
            code: -1001,
            userInfo: [NSLocalizedDescriptionKey:
                        "Could not resolve model '\(id)' with the installed mlx-libraries."]
        )
    }
}

// MARK: - Thin indirection points (resolved dynamically if present)

/// Captures a newer convenience loader if the symbol exists at link time.
/// When building against 2.25.x this will remain `nil`.
private enum _ConvenienceLoader {
    typealias LoaderFn = (_ id: String, _ preferQuantized: Bool) async throws -> LanguageModel
    static let shared: LoaderFn? = {
        // If future releases expose a static async `loadModel(id:preferQuantized:)`,
        // you can bind it here via a wrapper without changing call-sites.
        return nil
    }()
}

/// Optional direct loader hook for LLMs if a newer API provides it.
private enum _DirectLoader {
    #if canImport(MLXLLM)
    typealias LLMFn = (_ id: String, _ preferQuantized: Bool) async throws -> LanguageModel
    static let llm: LLMFn? = {
        // Leave nil under 2.25.x; future versions can be detected and used.
        return nil
    }()
    #else
    static let llm: Any? = nil
    #endif
}

// MARK: - Small conveniences to ease API drift

public extension GenerationOptions {
    /// Create options with common sensible defaults if your code assumed a different initializer.
    init(
        temperature: Float = 0.7,
        topP: Float = 0.95,
        maxTokens: Int = 512,
        presencePenalty: Float = 0.0,
        frequencyPenalty: Float = 0.0
    ) {
        self.init()
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }
}

