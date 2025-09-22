#import "AppDelegate.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>

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
  RNPrepareReactNativeApplication(application, self.turboModuleEnabled);

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
