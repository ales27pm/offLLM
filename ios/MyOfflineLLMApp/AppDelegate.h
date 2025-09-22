#import <UIKit/UIKit.h>
#import "ReactNativeFactoryCompat.h"

@interface AppDelegate : RNAppDelegateBaseClass <RN_APP_DELEGATE_PROTOCOLS>

@property (nonatomic, strong) UIWindow *window;

@end

#undef RN_APP_DELEGATE_PROTOCOLS
