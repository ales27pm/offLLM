#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RCTLogLevel) {
  RCTLogLevelTrace = 0,
  RCTLogLevelInfo = 1,
  RCTLogLevelWarning = 2,
  RCTLogLevelError = 3,
  RCTLogLevelFatal = 4
};

#define RCTLogInfo(...)
#define RCTLogWarn(...)
#define RCTLogError(...)
