#import "AppDelegate.h"

#if __has_include(<React-RCTAppDelegate/RCTAppSetupUtils.h>)
#import <React-RCTAppDelegate/RCTAppSetupUtils.h>
#define CR_RCT_APPSETUPUTILS_AVAILABLE 1
#elif __has_include(<React/RCTAppSetupUtils.h>)
#import <React/RCTAppSetupUtils.h>
#define CR_RCT_APPSETUPUTILS_AVAILABLE 1
#else
#define CR_RCT_APPSETUPUTILS_AVAILABLE 0
#endif

#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <React-RCTAppDelegate/RCTRootViewFactory.h>
#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>

#if CR_RCT_APPSETUPUTILS_AVAILABLE

#if defined(__has_builtin)
#if __has_builtin(__builtin_types_compatible_p)
#define CR_RCT_APPSETUP_HAS_TURBO_PARAM                                                    \
  __builtin_types_compatible_p(__typeof__(&RCTAppSetupPrepareApp), void (*)(id, BOOL))
#endif
#endif

#ifndef CR_RCT_APPSETUP_HAS_TURBO_PARAM
#define CR_RCT_APPSETUP_HAS_TURBO_PARAM 1
#endif

#if CR_RCT_APPSETUP_HAS_TURBO_PARAM
#define CR_RCT_PREPARE_APP(APP, TURBO) RCTAppSetupPrepareApp(APP, TURBO)
#else
#define CR_RCT_PREPARE_APP(APP, TURBO) RCTAppSetupPrepareApp(APP)
#endif

#else
#warning \
    "RCTAppSetupUtils header not found. The app will skip RCTAppSetupPrepareApp; ensure Pods are installed if you rely on it."
static inline void RCTAppSetupPrepareApp(id application, BOOL turboModuleEnabled)
{
  (void)application;
  (void)turboModuleEnabled;
}
#define CR_RCT_PREPARE_APP(APP, TURBO) RCTAppSetupPrepareApp(APP, TURBO)
#endif

static NSString *const kReactModuleNameInfoDictionaryKey = @"ReactNativeRootModuleName";
static NSString *const kDefaultReactModuleName = @"monGARS";

static NSString *ResolveReactModuleName(void)
{
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *configuredModuleName = [mainBundle objectForInfoDictionaryKey:kReactModuleNameInfoDictionaryKey];
  if (configuredModuleName.length > 0) {
    return configuredModuleName;
  }

  NSString *bundleName = [mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
  if (bundleName.length > 0) {
    return bundleName;
  }

  return kDefaultReactModuleName;
}

@interface AppDelegate ()
@property(nonatomic, strong) RCTReactNativeFactory *reactNativeFactory;
@property(nonatomic, copy) NSString *moduleName;
@property(nonatomic, copy, nullable) NSDictionary *initialProps;
@end

@implementation AppDelegate

- (instancetype)init
{
  self = [super init];
  if (self) {
    _moduleName = ResolveReactModuleName();
    _initialProps = nil;
  }
  return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  CR_RCT_PREPARE_APP(application, self.turboModuleEnabled);

  self.reactNativeFactory = [[RCTReactNativeFactory alloc] initWithDelegate:self];

  UIView *rootView = [self.reactNativeFactory.rootViewFactory viewWithModuleName:self.moduleName
                                                                initialProperties:self.initialProps
                                                                    launchOptions:launchOptions];

  if (rootView == nil) {
    NSString *message =
        [NSString stringWithFormat:@"[AppDelegate] Error: viewWithModuleName returned nil for module '%@'.", self.moduleName];
    NSLog(@"%@", message);
    NSCAssert(rootView != nil, @"%@", message);
    return NO;
  }

  UIViewController *rootViewController = [self createRootViewController];
  [self setRootView:rootView toRootViewController:rootViewController];

  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = rootViewController;
  [self.window makeKeyAndVisible];

  return YES;
}

- (NSURL *)bundleURL
{
  return [self sourceURLForBridge:nil];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
#else
  NSURL *bundleURL = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
  if (bundleURL == nil) {
    NSString *message =
        @"[AppDelegate] Error: Unable to locate main.jsbundle. Ensure the JS bundle is embedded in release builds.";
    NSLog(@"%@", message);
    NSCAssert(bundleURL != nil, @"%@", message);
    return nil;
  }
  return bundleURL;
#endif
}

@end
