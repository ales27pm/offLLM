#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(FilesTurboModule, NSObject)

RCT_EXTERN_METHOD(pickFile:(NSString *)type resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@interface FilesTurboModule () <UIDocumentPickerDelegate>
@property(nonatomic, strong) RCTPromiseResolveBlock resolver;
@property(nonatomic, strong) RCTPromiseRejectBlock rejecter;
@end

@implementation FilesTurboModule

RCT_EXPORT_METHOD(pickFile:(NSString *)type resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  self.resolver = resolve;
  self.rejecter = reject;
  dispatch_async(dispatch_get_main_queue(), ^{
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
    picker.allowsMultipleSelection = NO;
    picker.delegate = self;
    UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [root presentViewController:picker animated:YES completion:nil];
  });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  if (self.resolver && urls.count > 0) {
    self.resolver(@{ @"url": urls[0].absoluteString });
  } else if (self.rejecter) {
    self.rejecter(@"pick_error", @"No file selected", nil);
  }
  self.resolver = nil;
  self.rejecter = nil;
  [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  if (self.rejecter) self.rejecter(@"pick_cancel", @"User cancelled file picker", nil);
  self.resolver = nil;
  self.rejecter = nil;
  [controller dismissViewControllerAnimated:YES completion:nil];
}

@end

