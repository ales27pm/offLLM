import Foundation
import MLXLLM
import MLXLMCommon

/// Cross-version shims for MLX LLM snapshots.
/// We map our code to whichever concrete symbols exist in the checkout,
/// driven by compile-time flags emitted by a small detector script.
///
/// Flags that may be defined:
///  - MLX_FACTORY_LOADER: use LLMModelFactory instead of ChatModelLoader
///  - MLX_GENCONFIG: use GenerationConfig instead of GenerationOptions
public enum MLXCompat {
    // Session type is stable in both variants.
    public typealias ChatSession = MLXLLM.ChatSession

    #if MLX_FACTORY_LOADER
    public typealias ModelLoader = MLXLLM.LLMModelFactory
    #else
    public typealias ModelLoader = MLXLLM.ChatModelLoader
    #endif

    #if MLX_GENCONFIG
    public typealias GenerationOptions = MLXLLM.GenerationConfig
    #else
    public typealias GenerationOptions = MLXLLM.GenerationOptions
    #endif
}
