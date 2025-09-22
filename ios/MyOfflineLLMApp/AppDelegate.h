#import <UIKit/UIKit.h>

#import "ReactNativeFactoryCompat.h"

NS_ASSUME_NONNULL_BEGIN

#if RN_HAS_REACT_NATIVE_FACTORY
@interface AppDelegate : RCTDefaultReactNativeFactoryDelegate <UIApplicationDelegate>
#else
@interface AppDelegate : UIResponder <UIApplicationDelegate, RCTBridgeDelegate>
#endif

@property (nonatomic, strong) UIWindow *window;

@end

NS_ASSUME_NONNULL_END
