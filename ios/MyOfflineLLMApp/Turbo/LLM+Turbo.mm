#import <ReactCommon/RCTTurboModule.h>
#import <React/RCTLog.h>

#import "LLMSpecAutoloader.h"

@class LLM;
using namespace facebook::react;

@interface LLM (Turbo) <RCTTurboModule>
@end

@implementation LLM (Turbo)
RCT_EXPORT_MODULE();
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
#if LLM_SPEC_AUTOGEN_AVAILABLE
  return std::make_shared<LLMSpecJSI>(params);
#else
  RCTLogError(@"[LLM TurboModule] RN Codegen spec for LLM is missing. Run: yarn install && npx react-native codegen && (cd ios && pod install). Last attempted header: %s", LLM_SPEC_AUTOGEN_HEADER);
  return nullptr;
#endif
}
@end
