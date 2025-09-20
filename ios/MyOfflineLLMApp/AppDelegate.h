#import <Foundation/Foundation.h>

#if __has_include(<React/RCTAppDelegate.h>)
#import <React/RCTAppDelegate.h>
#elif __has_include(<React_RCTAppDelegate/RCTAppDelegate.h>)
#import <React_RCTAppDelegate/RCTAppDelegate.h>
#elif __has_include("RCTAppDelegate.h")
#import "RCTAppDelegate.h"
#else
#error "RCTAppDelegate header not found. Run 'bundle exec pod install' to generate React-RCTAppDelegate"
#endif

@interface AppDelegate : RCTAppDelegate
@end
