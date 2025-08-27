//  MLXTurboModule.mm
//  MyOfflineLLMApp
//
//  Created by ChatGPT on 2025-08-26.
//
//  This stub implementation provides compatibility with the
//  OffLLM iOS build without requiring the MLX/MLXLLM frameworks.
//  The original MLXTurboModule relied on Apple Silicon-only
//  machine learning libraries and custom optimizers that are
//  unavailable in this open source environment.  To ensure the
//  application compiles, this file defines a minimal TurboModule
//  which simply rejects all calls, indicating that MLX features
//  are not supported on iOS.

#import "React/RCTBridgeModule.h"

@interface MLXTurboModule : NSObject <RCTBridgeModule>
@end

@implementation MLXTurboModule

// Export the module to React Native.
RCT_EXPORT_MODULE();

/**
 * Attempts to load a machine learning model.  Since MLX is not
 * available in this environment, this method will reject the promise
 * with a descriptive error.  The parameters mirror the original
 * signature for compatibility.
 *
 * @param modelPath Path to the model file on disk.
 * @param resolver Promise resolver (unused).
 * @param rejecter Promise rejecter used to send the error back to JS.
 */
RCT_EXPORT_METHOD(loadModel:(NSString *)modelPath
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  rejecter(@"NOT_SUPPORTED", @"MLXTurboModule is not available on iOS", nil);
}

/**
 * Generates text from a prompt.  This stub rejects the call as the
 * underlying MLX model is not available.
 */
RCT_EXPORT_METHOD(generate:(NSString *)prompt
                  maxTokens:(nonnull NSNumber *)maxTokens
                  temperature:(double)temperature
                  useSparseAttention:(BOOL)useSparseAttention
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  rejecter(@"NOT_SUPPORTED", @"MLXTurboModule is not available on iOS", nil);
}

/**
 * Returns embeddings for a given text.  Always rejects as embeddings
 * cannot be computed without the MLX framework.
 */
RCT_EXPORT_METHOD(embed:(NSString *)text
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  rejecter(@"NOT_SUPPORTED", @"MLXTurboModule is not available on iOS", nil);
}

/**
 * Clears any internal KV cache.  This stub simply resolves with
 * success and an empty size to avoid breaking client code that
 * expects a response.
 */
RCT_EXPORT_METHOD(clearKVCache:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  resolver(@{ @"status": @"cleared", @"size": @0 });
}

/**
 * Records a message boundary in the prompt history.  No‑ops on iOS.
 */
RCT_EXPORT_METHOD(addMessageBoundary:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  resolver(@{ @"status": @"boundary added", @"count": @0 });
}

/**
 * Returns performance metrics such as cache size or inference time.
 * Provides dummy values since no inference occurs on iOS.
 */
RCT_EXPORT_METHOD(getPerformanceMetrics:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  resolver(@{
    @"totalInferenceTime": @0,
    @"inferenceCount": @0,
    @"averageInferenceTime": @0,
    @"currentCacheSize": @0,
    @"maxCacheSize": @0,
    @"thermalState": @0,
    @"usingSparseAttention": @NO,
    @"quantizationType": @"none"
  });
}

/**
 * Adjusts performance mode.  This stub simply resolves to acknowledge
 * the call without making any changes.
 */
RCT_EXPORT_METHOD(adjustPerformanceMode:(NSString *)mode
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)
{
  resolver(@{ @"status": @"noop" });
}

@end
