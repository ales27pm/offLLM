#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(PhotosTurboModule, NSObject)

RCT_EXTERN_METHOD(pickPhoto:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation PhotosTurboModule

RCT_EXPORT_METHOD(pickPhoto:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    if (status != PHAuthorizationStatusAuthorized) {
      reject(@"permission_denied", @"Photos access denied", nil);
      return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.image"];
    UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [root presentViewController:picker animated:YES completion:nil];
    // Placeholder completion block, actual implementation would use delegate
    picker.completionWithItemsHandler = ^(UIImagePickerController *pickerController, NSDictionary *info) {
      NSURL *url = info[UIImagePickerControllerImageURL];
      if (url) {
        resolve(@{ @"url": url.absoluteString });
      } else {
        reject(@"pick_error", @"No photo selected", nil);
      }
    };
  }];
}

@end

