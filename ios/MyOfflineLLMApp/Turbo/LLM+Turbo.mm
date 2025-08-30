#import <React/RCTTurboModule.h>
#import <ReactCommon/RCTTurboModule.h>
#if __has_include("AppSpec/NativeLLMSpec.h")
  #import "AppSpec/NativeLLMSpec.h"
#elif __has_include("NativeLLMSpec.h")
  #import "NativeLLMSpec.h"
#else
  #import "AppSpec.h"
#endif

@class LLM;
using namespace facebook::react;

@interface LLM (Turbo) <RCTTurboModule>
@end

@implementation LLM (Turbo)
RCT_EXPORT_MODULE();
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
  return std::make_shared<NativeLLMSpecJSI>(params);
}
@end
