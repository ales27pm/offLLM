#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(CallTurboModule, NSObject)

RCT_EXTERN_METHOD(getRecentCalls:(NSInteger)limit resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation CallTurboModule

RCT_EXPORT_METHOD(getRecentCalls:(NSInteger)limit resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(@[]);
}

@end

