#import <UIKit/UIKit.h>

#if __has_include(<React/RCTAppDelegate.h>)
#import <React/RCTAppDelegate.h>
#elif __has_include(<React_RCTAppDelegate/RCTAppDelegate.h>)
#import <React_RCTAppDelegate/RCTAppDelegate.h>
#elif __has_include("RCTAppDelegate.h")
#import "RCTAppDelegate.h"
#endif

#import "ReactNativeFactoryCompat.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : RNAppDelegateBaseClass <RN_APP_DELEGATE_PROTOCOLS>

@property (nonatomic, strong) UIWindow *window;

@end

NS_ASSUME_NONNULL_END

#undef RN_APP_DELEGATE_PROTOCOLS
