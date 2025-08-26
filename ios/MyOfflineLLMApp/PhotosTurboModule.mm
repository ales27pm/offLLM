#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(PhotosTurboModule, NSObject)

RCT_EXTERN_METHOD(pickPhoto:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@interface PhotosTurboModule () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic, strong) RCTPromiseResolveBlock resolver;
@property(nonatomic, strong) RCTPromiseRejectBlock rejecter;
@end

@implementation PhotosTurboModule

RCT_EXPORT_METHOD(pickPhoto:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  self.resolver = resolve;
  self.rejecter = reject;
  [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    if (status != PHAuthorizationStatusAuthorized) {
      if (self.rejecter) self.rejecter(@"permission_denied", @"Photos access denied", nil);
      self.resolver = nil;
      self.rejecter = nil;
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      UIImagePickerController *picker = [[UIImagePickerController alloc] init];
      picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
      picker.mediaTypes = @[@"public.image"];
      picker.delegate = self;
      UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
      [root presentViewController:picker animated:YES completion:nil];
    });
  }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
  NSURL *url = info[UIImagePickerControllerImageURL];
  if (self.resolver) self.resolver(@{ @"url": url.absoluteString ?: @"" });
  self.resolver = nil;
  self.rejecter = nil;
  [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  if (self.rejecter) self.rejecter(@"pick_cancel", @"User cancelled photo picker", nil);
  self.resolver = nil;
  self.rejecter = nil;
  [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

