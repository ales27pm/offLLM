#import <ReactCommon/RCTTurboModule.h>
#if __has_include("AppSpec/LLMSpec.h")
  #import "AppSpec/LLMSpec.h"
#elif __has_include("LLMSpec.h")
  #import "LLMSpec.h"
#else
// Prefer the umbrella header from FBReactNativeSpec so AppSpec.h always matches
// the installed Pods; fall back to local headers for OSS or non-Pod builds.
#if __has_include(<FBReactNativeSpec/AppSpec.h>)
#import <FBReactNativeSpec/AppSpec.h>
#elif __has_include("FBReactNativeSpec/AppSpec.h")
#import "FBReactNativeSpec/AppSpec.h"
#else
#import "AppSpec.h"
#endif
#endif

@class LLM;
using namespace facebook::react;

@interface LLM (Turbo) <RCTTurboModule>
@end

@implementation LLM (Turbo)
RCT_EXPORT_MODULE();
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
  return std::make_shared<LLMSpecJSI>(params);
}
@end
