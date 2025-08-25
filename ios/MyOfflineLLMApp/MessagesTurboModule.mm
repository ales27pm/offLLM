#import <React/RCTBridgeModule.h>
#import <MessageUI/MessageUI.h>

@interface MessagesTurboModule : NSObject <RCTBridgeModule>
@end

@implementation MessagesTurboModule

RCT_EXPORT_MODULE();

RCT_REMAP_METHOD(sendMessage,
                 phoneNumber:(NSString *)phoneNumber
                 body:(NSString *)body
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![MFMessageComposeViewController canSendText]) {
    reject(@"NOT_SUPPORTED", @"SMS not available", nil);
    return;
  }

  NSDictionary *payload = @{ @"phoneNumber": phoneNumber, @"body": body };
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SendSMSNotification" object:nil userInfo:payload];
  resolve(@{ @"success": @YES });
}

@end
