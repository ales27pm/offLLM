#import "AppDelegate.h"

#if __has_include(<React-RCTAppDelegate/RCTAppSetupUtils.h>)
#import <React-RCTAppDelegate/RCTAppSetupUtils.h>
#define CR_RCT_APPSETUPUTILS_AVAILABLE 1
#elif __has_include(<React/RCTAppSetupUtils.h>)
#import <React/RCTAppSetupUtils.h>
#define CR_RCT_APPSETUPUTILS_AVAILABLE 1
#elif __has_include("RCTAppSetupUtils.h")
#import "RCTAppSetupUtils.h"
#define CR_RCT_APPSETUPUTILS_AVAILABLE 1
#else
#define CR_RCT_APPSETUPUTILS_AVAILABLE 0
#endif

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

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Prepare the React Native environment.
  CR_RCT_PREPARE_APP(application, [self turboModuleEnabled]);
  // Name must match the "name" field in app.json.
  self.moduleName = @"monGARS";
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
