#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

void RCTRegisterModule(Class cls) {}

typedef NS_ENUM(NSInteger, RCTLogLevel) {
  RCTLogLevelTrace = 0,
  RCTLogLevelInfo = 1,
  RCTLogLevelWarning = 2,
  RCTLogLevelError = 3,
  RCTLogLevelFatal = 4
};

void _RCTLogNativeInternal(RCTLogLevel level, const char *fileName, int lineNumber, NSString *message, ...) {}

UIViewController *RCTPresentedViewController(void) {
  return nil;
}

