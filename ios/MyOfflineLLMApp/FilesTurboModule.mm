#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(FilesTurboModule, NSObject)

RCT_EXTERN_METHOD(pickFile:(NSString *)type resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation FilesTurboModule

RCT_EXPORT_METHOD(pickFile:(NSString *)type resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
  picker.allowsMultipleSelection = NO;
  UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
  [root presentViewController:picker animated:YES completion:nil];
  // Placeholder completion handler, actual implementation would use delegate
  picker.completionHandler = ^(NSArray<NSURL *> *urls) {
    if (urls.count > 0) {
      resolve(@{ @"url": urls[0].absoluteString });
    } else {
      reject(@"pick_error", @"No file selected", nil);
    }
  };
}

@end

