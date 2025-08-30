#import "AppDelegate.h"
#import <React/RCTAppSetupUtils.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Prepare the React Native environment (new architecture).
  RCTAppSetupPrepareApp(application);
  // This must match the "name" in app.json ("MyOfflineLLMApp").
  self.moduleName = @"MyOfflineLLMApp";
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
