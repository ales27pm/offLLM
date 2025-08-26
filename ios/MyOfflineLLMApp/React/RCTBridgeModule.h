#import <Foundation/Foundation.h>

typedef void (^RCTPromiseResolveBlock)(id result);
typedef void (^RCTPromiseRejectBlock)(NSString *code, NSString *message, NSError *error);

@protocol RCTBridgeModule <NSObject>
@optional
+ (BOOL)requiresMainQueueSetup;
@end

#define RCT_EXPORT_MODULE(...)
#define RCT_EXPORT_METHOD(method) - (void)method
#define RCT_REMAP_METHOD(js_name, method, ...) - (void)method __VA_ARGS__
#define RCT_EXTERN_MODULE(name, superClass) name : superClass
#define RCT_EXTERN_METHOD(method) - (void)method;
