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

    // Prefer newer LLMModelFactory; fall back to legacy only on older trees.
    #if canImport(MLXLLM)
    @available(*, unavailable, message: "Build-time guard only; use the conditional below.")
    private typealias _LLMModelFactory_AvailabilityProbe = MLXLLM.LLMModelFactory
    #if canImport(MLXLLM) && compiler(>=5.7)
    #if canImport(MLXLLM)
    // Prefer LLMModelFactory when available; otherwise fall back to ChatModelLoader.
    #if swift(>=5.7)
    public typealias ModelLoader = (
        (AnyObject & Any).Type == (MLXLLM.LLMModelFactory).self
    ) ? MLXLLM.LLMModelFactory : MLXLLM.ChatModelLoader
    #else
    public typealias ModelLoader = MLXLLM.ChatModelLoader
    #endif
    #endif
    #else
    public typealias ModelLoader = MLXLLM.ChatModelLoader
    #endif
    #else
    #error("MLXLLM module is unavailable")
    #endif

    // “GenerationOptions” → “GenerationConfig” in newer snapshots.
    #if canImport(MLXLMCommon)
    public typealias GenerationOptions = MLXLMCommon.GenerationConfig
    #elseif canImport(MLXLLM)
    public typealias GenerationOptions = MLXLLM.GenerationConfig
    #else
    #error("GenerationConfig not available")
    #endif
}
#endif
