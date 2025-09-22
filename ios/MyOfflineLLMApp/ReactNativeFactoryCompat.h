#pragma once

#import <Foundation/Foundation.h>

#if __has_include(<React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>)
#define RN_HAS_REACT_NATIVE_FACTORY 1
#import <React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>
#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <React-RCTAppDelegate/RCTRootViewFactory.h>
#elif __has_include(<React/RCTDefaultReactNativeFactoryDelegate.h>)
#define RN_HAS_REACT_NATIVE_FACTORY 1
#import <React/RCTDefaultReactNativeFactoryDelegate.h>
#import <React/RCTReactNativeFactory.h>
#import <React/RCTRootViewFactory.h>
#else
#define RN_HAS_REACT_NATIVE_FACTORY 0
#endif

#if !RN_HAS_REACT_NATIVE_FACTORY
#import <React/RCTBridge.h>
#import <React/RCTBridgeDelegate.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>
#endif

#if __has_include(<React-RCTAppDelegate/RCTAppSetupUtils.h>)
#import <React-RCTAppDelegate/RCTAppSetupUtils.h>
#define RN_APPSETUPUTILS_AVAILABLE 1
#elif __has_include(<React/RCTAppSetupUtils.h>)
#import <React/RCTAppSetupUtils.h>
#define RN_APPSETUPUTILS_AVAILABLE 1
#else
#define RN_APPSETUPUTILS_AVAILABLE 0
#endif

#if RN_APPSETUPUTILS_AVAILABLE

#if defined(__has_builtin)
#if __has_builtin(__builtin_types_compatible_p)
#define RN_APPSETUP_HAS_TURBO_PARAM                                                             \
  __builtin_types_compatible_p(__typeof__(&RCTAppSetupPrepareApp), void (*)(id, BOOL))
#endif
#endif

#ifndef RN_APPSETUP_HAS_TURBO_PARAM
#define RN_APPSETUP_HAS_TURBO_PARAM 1
#endif

static inline void RNPrepareReactNativeApplication(id application, BOOL turboModuleEnabled)
{
#if RN_APPSETUP_HAS_TURBO_PARAM
  RCTAppSetupPrepareApp(application, turboModuleEnabled);
#else
  RCTAppSetupPrepareApp(application);
#endif
}

#else

static inline void RNPrepareReactNativeApplication(id application, BOOL turboModuleEnabled)
{
  (void)application;
  (void)turboModuleEnabled;
}

#endif

#undef RN_APPSETUP_HAS_TURBO_PARAM
#undef RN_APPSETUPUTILS_AVAILABLE

