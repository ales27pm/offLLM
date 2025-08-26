#import <Foundation/Foundation.h>
#import "RCTBridgeModule.h"

@interface RCTEventEmitter : NSObject <RCTBridgeModule>
- (void)sendEventWithName:(NSString *)name body:(id)body;
- (NSArray<NSString *> *)supportedEvents;
@end
