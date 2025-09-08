#import "AppDelegate.h"
#import <React/RCTAppSetupUtils.h>

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
