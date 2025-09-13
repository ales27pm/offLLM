// Guard optional MLX modules so builds succeed even if packages fail to resolve.
#if canImport(MLXLLM) || canImport(MLXLMCommon)
import Foundation
#if canImport(MLXLLM)
import MLXLLM
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif
#if canImport(MLX)
import MLX
#endif
#if canImport(MLXNN)
import MLXNN
#endif

public enum MLXCompat {
    // ChatSession moved between modules in some snapshots.
    #if canImport(MLXLMCommon)
    public typealias ChatSession = MLXLMCommon.ChatSession
    #elseif canImport(MLXLLM)
    public typealias ChatSession = MLXLLM.ChatSession
    #else
    #error("Neither MLXLMCommon nor MLXLLM is available")
    #endif

    // Prefer newer LLMModelFactory; fall back to legacy loader when absent.
    #if canImport(MLXLLM)
    #if MLX_FACTORY_LOADER
    public typealias ModelLoader = MLXLLM.LLMModelFactory
    #else
    public typealias ModelLoader = MLXLLM.ChatModelLoader
    #endif
    #else
    #error("MLXLLM module is unavailable")
    #endif

    // “GenerationOptions” was renamed to “GenerationConfig” in some snapshots.
    // Alias to whichever symbol is available so call sites can remain stable.
    #if canImport(MLXLMCommon)
    #if MLX_GENCONFIG
    public typealias GenerationOptions = MLXLMCommon.GenerationConfig
    #else
    public typealias GenerationOptions = MLXLMCommon.GenerationOptions
    #endif
    #elseif canImport(MLXLLM)
    #if MLX_GENCONFIG
    public typealias GenerationOptions = MLXLLM.GenerationConfig
    #else
    public typealias GenerationOptions = MLXLLM.GenerationOptions
    #endif
    #else
    #error("Generation configuration type not available")
    #endif
}
#endif
