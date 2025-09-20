#import "AppDelegate.h"

#if __has_include(<React/RCTAppSetupUtils.h>)
#import <React/RCTAppSetupUtils.h>
#elif __has_include(<React_RCTAppDelegate/RCTAppSetupUtils.h>)
#import <React_RCTAppDelegate/RCTAppSetupUtils.h>
#elif __has_include("RCTAppSetupUtils.h")
#import "RCTAppSetupUtils.h"
#else
#warning "RCTAppSetupUtils header not found. The app will skip RCTAppSetupPrepareApp; ensure Pods are installed if you rely on it."
static inline void RCTAppSetupPrepareApp(id application) {}
#endif

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Prepare the React Native environment.
  RCTAppSetupPrepareApp(application);
  // Name must match the "name" field in app.json.
  self.moduleName = @"monGARS";
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
