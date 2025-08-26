#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(BrightnessTurboModule, NSObject)

RCT_EXTERN_METHOD(setBrightness:(double)level resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation BrightnessTurboModule

RCT_EXPORT_METHOD(setBrightness:(double)level resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIScreen mainScreen].brightness = level;
    resolve(@{ @"success": @YES });
  });
}

@end

