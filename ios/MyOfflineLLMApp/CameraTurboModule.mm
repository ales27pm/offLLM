#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(CameraTurboModule, NSObject)

RCT_EXTERN_METHOD(takePhoto:(double)quality resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation CameraTurboModule

RCT_EXPORT_METHOD(takePhoto:(double)quality resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  UIImagePickerController *picker = [[UIImagePickerController alloc] init];
  picker.sourceType = UIImagePickerControllerSourceTypeCamera;
  picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
  UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
  [root presentViewController:picker animated:YES completion:nil];
  // Placeholder completion block, actual implementation would use delegate
  picker.completionWithItemsHandler = ^(UIImagePickerController *pickerController, NSDictionary *info) {
    NSURL *url = info[UIImagePickerControllerImageURL];
    if (url) {
      resolve(@{ @"url": url.absoluteString });
    } else {
      reject(@"capture_error", @"No photo captured", nil);
    }
  };
}

@end

