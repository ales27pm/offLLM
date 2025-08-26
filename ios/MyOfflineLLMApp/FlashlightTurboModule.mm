#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>

@interface RCT_EXTERN_MODULE(FlashlightTurboModule, NSObject)

RCT_EXTERN_METHOD(setTorchMode:(BOOL)on resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation FlashlightTurboModule

RCT_EXPORT_METHOD(setTorchMode:(BOOL)on resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  if ([device hasTorch]) {
    NSError *error = nil;
    [device lockForConfiguration:&error];
    if (error) {
      reject(@"lock_error", error.localizedDescription, error);
      return;
    }
    device.torchMode = on ? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
    [device unlockForConfiguration];
    resolve(@{ @"success": @YES });
  } else {
    reject(@"no_torch", @"Device has no flashlight", nil);
  }
}

@end

