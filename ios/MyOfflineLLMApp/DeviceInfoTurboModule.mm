#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

@interface RCT_EXTERN_MODULE(DeviceInfoTurboModule, NSObject)

RCT_EXTERN_METHOD(getDeviceInfo:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation DeviceInfoTurboModule

RCT_EXPORT_METHOD(getDeviceInfo:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  struct utsname systemInfo;
  uname(&systemInfo);
  NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
  UIDevice *device = [UIDevice currentDevice];
  resolve(@{
    @"model": machine,
    @"systemName": device.systemName,
    @"systemVersion": device.systemVersion,
    @"name": device.name,
    @"identifierForVendor": device.identifierForVendor.UUIDString ?: @"unknown",
    @"isLowPowerMode": @([NSProcessInfo processInfo].isLowPowerModeEnabled)
  });
}

@end

