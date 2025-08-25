#import <React/RCTBridgeModule.h>
#import <React/RCTLog.h>
#import <MLX/MLX.h>
#import <MLXLLM/MLXLLM.h>
#import "ANEOptimizer.h"
#import "ThermalManager.h"

@interface RCT_EXTERN_MODULE(MLXTurboModule, NSObject)

RCT_EXTERN_METHOD(loadModel:(NSString *)modelPath
                 resolver:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(generate:(NSString *)prompt
                 maxTokens:(NSNumber *)maxTokens
                 temperature:(float)temperature
                 useSparseAttention:(BOOL)useSparseAttention
                 resolver:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(embed:(NSString *)text
                 resolver:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(clearKVCache:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(addMessageBoundary:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(getPerformanceMetrics:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(adjustPerformanceMode:(NSString *)mode
                 resolver:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter)

@end

@implementation MLXTurboModule {
  MLXLLMModel *_model;
  MLXLLMTokenizer *_tokenizer;
  NSMutableArray *_kvCache;
  NSMutableArray *_messageBoundaries;
  NSUInteger _maxCacheSize;
  BOOL _isQuantized;
  BOOL _useSparseAttention;
  ANEOptimizer *_aneOptimizer;
  ThermalManager *_thermalManager;
  NSDate *_lastInferenceTime;
  NSTimeInterval _totalInferenceTime;
  NSUInteger _inferenceCount;
  NSString *_quantizationType;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _maxCacheSize = 512;
    _kvCache = [NSMutableArray arrayWithCapacity:_maxCacheSize];
    _messageBoundaries = [NSMutableArray array];
    _aneOptimizer = [[ANEOptimizer alloc] init];
    _thermalManager = [[ThermalManager alloc] init];
    _totalInferenceTime = 0;
    _inferenceCount = 0;
    _quantizationType = @"none";
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleThermalStateChange:)
                                                 name:ThermalStateChangedNotification
                                               object:nil];
  }
  return self;
}

- (void)handleThermalStateChange:(NSNotification *)notification {
  ThermalState state = [notification.userInfo[@"state"] integerValue];
  [self adjustPerformanceForThermalState:state];
}

- (void)adjustPerformanceForThermalState:(ThermalState)state {
  switch (state) {
    case ThermalStateNominal:
      _maxCacheSize = _isQuantized ? 2048 : 1024;
      _useSparseAttention = NO;
      break;
    case ThermalStateFair:
      _maxCacheSize = _isQuantized ? 1024 : 512;
      _useSparseAttention = NO;
      break;
    case ThermalStateSerious:
      _maxCacheSize = _isQuantized ? 512 : 256;
      _useSparseAttention = YES;
      break;
    case ThermalStateCritical:
      _maxCacheSize = 256;
      _useSparseAttention = YES;
      break;
  }
}

- (void)loadModel:(NSString *)modelPath
         resolver:(RCTPromiseResolveBlock)resolver
         rejecter:(RCTPromiseRejectBlock)rejecter {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @try {
      [MLX setup];
      
      NSArray *quantizationMarkers = @[@"Q4_0", @"Q5_0", @"Q2_K", @"Q3_K_S", @"Q3_K_M", @"Q3_K_L", 
                                      @"Q4_K_S", @"Q4_K_M", @"Q5_K_S", @"Q5_K_M", @"Q6_K", @"MobileQuant"];
      BOOL isQuantized = NO;
      NSString *detectedQuantization = @"none";
      
      for (NSString *marker in quantizationMarkers) {
        if ([modelPath rangeOfString:marker].location != NSNotFound) {
          isQuantized = YES;
          detectedQuantization = marker;
          self->_quantizationType = marker;
          break;
        }
      }
      
      MLXLLMModelOptions *options = [[MLXLLMModelOptions alloc] init];
      options.quantize = isQuantized;
      
      if (isQuantized) {
        options.contextLength = 8192;
        options.useSparseAttention = YES;
      }
      
      if ([_aneOptimizer isANEAvailable]) {
        options = [_aneOptimizer optimizeModelOptions:options];
      }
      
      NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
      self->_model = [MLXLLMModel modelWithContentsOfURL:modelURL options:options];
      
      if (!self->_model) {
        @throw [NSException exceptionWithName:@"ModelLoadError"
                                      reason:@"Failed to load MLX model"
                                    userInfo:nil];
      }
      
      self->_tokenizer = [MLXLLMTokenizer tokenizerWithModel:self->_model];
      
      if (!self->_tokenizer) {
        @throw [NSException exceptionWithName:@"TokenizerError"
                                      reason:@"Failed to initialize tokenizer"
                                    userInfo:nil];
      }
      
      [self configureDynamicCacheSize];
      
      [self->_kvCache removeAllObjects];
      [self->_messageBoundaries removeAllObjects];
      
      RCTLogInfo(@"Model loaded successfully: %@ (quantized: %@)", modelPath, detectedQuantization);
      resolver(@{
        @"status": @"loaded", 
        @"contextSize": @(isQuantized ? 8192 : 4096),
        @"model": modelPath,
        @"quantized": @(isQuantized),
        @"quantizationType": detectedQuantization,
        @"supportsSparseAttention": @(YES)
      });
    } @catch (NSException *exception) {
      NSString *errorMsg = [NSString stringWithFormat:@"Failed to load model: %@", exception.reason];
      rejecter(@"LOAD_ERROR", errorMsg, nil);
    }
  });
}

- (void)generate:(NSString *)prompt
       maxTokens:(NSNumber *)maxTokens
     temperature:(float)temperature
useSparseAttention:(BOOL)useSparseAttention
        resolver:(RCTPromiseResolveBlock)resolver
        rejecter:(RCTPromiseRejectBlock)rejecter {
  if (!_model || !_tokenizer) {
    rejecter(@"NO_MODEL", @"Model not loaded", nil);
    return;
  }
  
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @try {
      NSDate *startTime = [NSDate date];
      
      NSArray<NSNumber *> *inputTokens = [self->_tokenizer encode:prompt];
      
      [self addMessageBoundary];
      
      [self->_kvCache addObjectsFromArray:inputTokens];
      [self trimCache];
      
      MLXLLMGenerateOptions *options = [[MLXLLMGenerateOptions alloc] init];
      options.maxTokens = [maxTokens intValue];
      options.temperature = temperature;
      options.kvCache = self->_kvCache;
      options.useSparseAttention = useSparseAttention || self->_useSparseAttention;
      
      NSArray<NSNumber *> *generatedTokens = [self->_model generateWithInputTokens:inputTokens options:options];
      
      [self->_kvCache addObjectsFromArray:generatedTokens];
      [self trimCache];
      
      NSString *response = [self->_tokenizer decode:generatedTokens];
      
      NSTimeInterval inferenceTime = -[startTime timeIntervalSinceNow];
      self->_totalInferenceTime += inferenceTime;
      self->_inferenceCount++;
      
      resolver(@{
        @"text": response,
        @"tokensGenerated": @(generatedTokens.count),
        @"kvCacheSize": @(self->_kvCache.count),
        @"kvCacheMax": @(self->_maxCacheSize),
        @"inferenceTime": @(inferenceTime),
        @"usedSparseAttention": @(options.useSparseAttention),
        @"quantizationType": self->_quantizationType
      });
    } @catch (NSException *exception) {
      NSString *errorMsg = [NSString stringWithFormat:@"Generation failed: %@", exception.reason];
      rejecter(@"GENERATE_ERROR", errorMsg, nil);
    }
  });
}

- (void)getPerformanceMetrics:(RCTPromiseResolveBlock)resolver
                    rejecter:(RCTPromiseRejectBlock)rejecter {
  NSTimeInterval avgInferenceTime = _inferenceCount > 0 ? _totalInferenceTime / _inferenceCount : 0;
  
  resolver(@{
    @"totalInferenceTime": @(_totalInferenceTime),
    @"inferenceCount": @(_inferenceCount),
    @"averageInferenceTime": @(avgInferenceTime),
    @"currentCacheSize": @(_kvCache.count),
    @"maxCacheSize": @(_maxCacheSize),
    @"thermalState": @([_thermalManager currentThermalState]),
    @"usingSparseAttention": @(_useSparseAttention),
    @"quantizationType": _quantizationType
  });
}

- (void)embed:(NSString *)text
     resolver:(RCTPromiseResolveBlock)resolver
     rejecter:(RCTPromiseRejectBlock)rejecter {
  if (!_model || !_tokenizer) {
    rejecter(@"NO_MODEL", @"Model not loaded", nil);
    return;
  }
  
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @try {
      NSArray<NSNumber *> *tokens = [self->_tokenizer encode:text];
      MLXArray *embeddings = [self->_model embedTokens:tokens];
      
      NSMutableArray *embeddingArray = [NSMutableArray array];
      float *data = (float *)[embeddings data];
      NSUInteger count = [embeddings count];
      
      for (NSUInteger i = 0; i < count; i++) {
        [embeddingArray addObject:@(data[i])];
      }
      
      resolver(embeddingArray);
    } @catch (NSException *exception) {
      NSString *errorMsg = [NSString stringWithFormat:@"Embedding failed: %@", exception.reason];
      rejecter(@"EMBED_ERROR", errorMsg, nil);
    }
  });
}

- (void)clearKVCache:(RCTPromiseResolveBlock)resolver
            rejecter:(RCTPromiseRejectBlock)rejecter {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @try {
      [self->_kvCache removeAllObjects];
      [self->_messageBoundaries removeAllObjects];
      resolver(@{@"status": @"cleared", @"size": @(0)});
    } @catch (NSException *exception) {
      NSString *errorMsg = [NSString stringWithFormat:@"Failed to clear KV cache: %@", exception.reason];
      rejecter(@"CACHE_ERROR", errorMsg, nil);
    }
  });
}

- (void)addMessageBoundary:(RCTPromiseResolveBlock)resolver
                 rejecter:(RCTPromiseRejectBlock)rejecter {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @try {
      [self addMessageBoundary];
      resolver(@{@"status": @"boundary added", @"count": @(self->_messageBoundaries.count)});
    } @catch (NSException *exception) {
      NSString *errorMsg = [NSString stringWithFormat:@"Failed to add boundary: %@", exception.reason];
      rejecter(@"BOUNDARY_ERROR", errorMsg, nil);
    }
  });
}

- (void)addMessageBoundary {
  [self->_messageBoundaries addObject:@(self->_kvCache.count)];
}

- (void)trimCache {
  if (self->_kvCache.count <= self->_maxCacheSize) return;
  
  if (self->_messageBoundaries.count > 1) {
    NSUInteger trimIndex = 0;
    for (NSUInteger i = 0; i < self->_messageBoundaries.count - 1; i++) {
      NSNumber *boundary = self->_messageBoundaries[i];
      if (self->_kvCache.count - boundary.intValue <= self->_maxCacheSize) {
        trimIndex = boundary.intValue;
        break;
      }
    }
    
    if (trimIndex > 0) {
      [self->_kvCache removeObjectsInRange:NSMakeRange(0, trimIndex)];
      NSMutableArray *newBoundaries = [NSMutableArray array];
      for (NSNumber *boundary in self->_messageBoundaries) {
        if (boundary.intValue > trimIndex) {
          [newBoundaries addObject:@(boundary.intValue - trimIndex)];
        }
      }
      self->_messageBoundaries = newBoundaries;
      return;
    }
  }
  
  NSUInteger excess = self->_kvCache.count - self->_maxCacheSize;
  [self->_kvCache removeObjectsInRange:NSMakeRange(0, excess)];
}

- (void)configureDynamicCacheSize {
  NSUInteger totalMemory = [[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024);
  if (totalMemory > 8000) {
    _maxCacheSize = _isQuantized ? 4096 : 2048;
  } else if (totalMemory > 4000) {
    _maxCacheSize = _isQuantized ? 2048 : 1024;
  } else {
    _maxCacheSize = 512;
  }
}

@end
