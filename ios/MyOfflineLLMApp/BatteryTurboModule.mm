#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(BatteryTurboModule, NSObject)

RCT_EXTERN_METHOD(getBatteryInfo:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation BatteryTurboModule

RCT_EXPORT_METHOD(getBatteryInfo:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  float level = [UIDevice currentDevice].batteryLevel;
  UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
  resolve(@{
    @"level": @(level * 100),
    @"state": @(state)
  });
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
}

@end

