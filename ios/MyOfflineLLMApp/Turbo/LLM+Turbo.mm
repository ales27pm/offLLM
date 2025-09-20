#import <ReactCommon/RCTTurboModule.h>

// Robust TurboModule spec includes with multiple RN codegen fallbacks
#if __has_include("AppSpec/LLMSpec.h")
  #import "AppSpec/LLMSpec.h"
#elif __has_include("AppSpecs/LLMSpec.h")
  #import "AppSpecs/LLMSpec.h"
#elif __has_include("LLMSpec.h")
  #import "LLMSpec.h"
// Then umbrella RN codegen headers (modern RN)
#elif __has_include(<FBReactNativeSpec/FBReactNativeSpec.h>)
  #import <FBReactNativeSpec/FBReactNativeSpec.h>
#elif __has_include(<React-Codegen/FBReactNativeSpec/FBReactNativeSpec.h>)
  #import <React-Codegen/FBReactNativeSpec/FBReactNativeSpec.h>
#elif __has_include("FBReactNativeSpec/FBReactNativeSpec.h")
  #import "FBReactNativeSpec/FBReactNativeSpec.h"
// Legacy FBReactNativeSpec tree under Pods public headers
#elif __has_include("FBReactNativeSpec/AppSpec.h")
  #import "FBReactNativeSpec/AppSpec.h"
#elif __has_include(<FBReactNativeSpec/AppSpec.h>)
  #import <FBReactNativeSpec/AppSpec.h>
// Last resort (local workspace)
#elif __has_include("AppSpec.h")
  #import "AppSpec.h"
#else
  #warning "LLM+Turbo.mm: No Codegen spec header found. Ensure RN codegen ran and Pods installed."
#endif

#include <cassert>

@class LLM;
using namespace facebook::react;

@interface LLM (Turbo) <RCTTurboModule>
@end

@implementation LLM (Turbo)
RCT_EXPORT_MODULE();
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
#if __has_include("AppSpec/LLMSpec.h") || __has_include("AppSpecs/LLMSpec.h") || __has_include("LLMSpec.h") || \
    __has_include(<FBReactNativeSpec/FBReactNativeSpec.h>) || __has_include(<React-Codegen/FBReactNativeSpec/FBReactNativeSpec.h>) || \
    __has_include("FBReactNativeSpec/FBReactNativeSpec.h") || __has_include("FBReactNativeSpec/AppSpec.h") || \
    __has_include("AppSpec.h")
  return std::make_shared<LLMSpecJSI>(params);
#else
  assert(false && "RN Codegen spec for LLM is missing. Run: yarn install && npx react-native codegen && (cd ios && pod install)");
  return nullptr;
#endif
}
@end
