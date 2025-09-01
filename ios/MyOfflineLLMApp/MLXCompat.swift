import Foundation
#if canImport(MLXLLM)
import MLXLLM
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

/// Cross-version shims for MLX LLM snapshots.
/// We map our code to whichever concrete symbols exist in the checkout,
/// driven by compile-time flags emitted by a small detector script.
///
/// Flags that may be defined:
///  - MLX_FACTORY_LOADER: use LLMModelFactory instead of ChatModelLoader
///  - MLX_GENCONFIG: use GenerationConfig instead of GenerationOptions
public enum MLXCompat {
    // ChatSession moved in some snapshots from MLXLLM -> MLXLMCommon.
    #if canImport(MLXLMCommon)
    public typealias ChatSession = MLXLMCommon.ChatSession
    #elseif canImport(MLXLLM)
    public typealias ChatSession = MLXLLM.ChatSession
    #else
    #error("Neither MLXLMCommon nor MLXLLM is available")
    #endif

    #if MLX_FACTORY_LOADER
    // Newer factory-style loader lives in MLXLLM.
    #if canImport(MLXLLM)
    public typealias ModelLoader = MLXLLM.LLMModelFactory
    #else
    #error("MLX_FACTORY_LOADER set, but MLXLLM not available")
    #endif
    #else
    // Legacy ChatModelLoader lives in MLXLLM.
    #if canImport(MLXLLM)
    public typealias ModelLoader = MLXLLM.ChatModelLoader
    #else
    #error("ChatModelLoader expected in MLXLLM but module is unavailable")
    #endif
    #endif

    #if MLX_GENCONFIG
    // Newer name: GenerationConfig. Prefer MLXLMCommon if present.
    #if canImport(MLXLMCommon)
    public typealias GenerationOptions = MLXLMCommon.GenerationConfig
    #elseif canImport(MLXLLM)
    public typealias GenerationOptions = MLXLLM.GenerationConfig
    #else
    #error("GenerationConfig not available")
    #endif
    #else
    // Older name: GenerationOptions. Prefer MLXLMCommon if present.
    #if canImport(MLXLMCommon)
    public typealias GenerationOptions = MLXLMCommon.GenerationOptions
    #elseif canImport(MLXLLM)
    public typealias GenerationOptions = MLXLLM.GenerationOptions
    #else
    #error("GenerationOptions not available")
    #endif
    #endif
}
