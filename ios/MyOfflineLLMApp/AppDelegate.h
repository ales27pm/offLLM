#import <UIKit/UIKit.h>

#if __has_include(<React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>)
#import <React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>
#elif __has_include(<React/RCTDefaultReactNativeFactoryDelegate.h>)
#import <React/RCTDefaultReactNativeFactoryDelegate.h>
#elif __has_include("RCTDefaultReactNativeFactoryDelegate.h")
#import "RCTDefaultReactNativeFactoryDelegate.h"
#endif

#import "ReactNativeFactoryCompat.h"

NS_ASSUME_NONNULL_BEGIN

#if RN_HAS_REACT_NATIVE_FACTORY
@interface AppDelegate : RCTDefaultReactNativeFactoryDelegate <UIApplicationDelegate>
#else
@class RCTBridge;
@protocol RCTBridgeDelegate;

@interface AppDelegate : UIResponder <UIApplicationDelegate, RCTBridgeDelegate>
#endif

@property (nonatomic, strong) UIWindow *window;

@end

NS_ASSUME_NONNULL_END
