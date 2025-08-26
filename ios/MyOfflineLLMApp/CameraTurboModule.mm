#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(CameraTurboModule, NSObject)

RCT_EXTERN_METHOD(takePhoto:(double)quality resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@interface CameraTurboModule () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic, strong) RCTPromiseResolveBlock resolver;
@property(nonatomic, strong) RCTPromiseRejectBlock rejecter;
@end

@implementation CameraTurboModule

RCT_EXPORT_METHOD(takePhoto:(double)quality resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  self.resolver = resolve;
  self.rejecter = reject;
  dispatch_async(dispatch_get_main_queue(), ^{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    picker.delegate = self;
    UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [root presentViewController:picker animated:YES completion:nil];
  });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
  NSURL *url = info[UIImagePickerControllerImageURL];
  if (self.resolver) self.resolver(@{ @"url": url.absoluteString ?: @"" });
  self.resolver = nil;
  self.rejecter = nil;
  [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  if (self.rejecter) self.rejecter(@"capture_cancel", @"User cancelled camera", nil);
  self.resolver = nil;
  self.rejecter = nil;
  [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

