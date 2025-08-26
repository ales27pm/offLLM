#import <React/RCTBridgeModule.h>
#import <CoreMotion/CoreMotion.h>

@interface RCT_EXTERN_MODULE(SensorsTurboModule, NSObject)

RCT_EXTERN_METHOD(getSensorData:(NSString *)type duration:(NSInteger)duration resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation SensorsTurboModule {
  CMMotionManager *_motionManager;
}

RCT_EXPORT_METHOD(getSensorData:(NSString *)type duration:(NSInteger)duration resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  _motionManager = [[CMMotionManager alloc] init];
  if ([type isEqualToString:@"accelerometer"]) {
    _motionManager.accelerometerUpdateInterval = 0.1;
    [_motionManager startAccelerometerUpdates];
  } else if ([type isEqualToString:@"gyroscope"]) {
    _motionManager.gyroUpdateInterval = 0.1;
    [_motionManager startGyroUpdates];
  } else if ([type isEqualToString:@"magnetometer"]) {
    _motionManager.magnetometerUpdateInterval = 0.1;
    [_motionManager startMagnetometerUpdates];
  } else {
    reject(@"invalid_type", @"Unsupported sensor type", nil);
    return;
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration / 1000.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    NSDictionary *data;
    if ([type isEqualToString:@"accelerometer"]) {
      CMAccelerometerData *acc = self->_motionManager.accelerometerData;
      data = @{
        @"x": @(acc.acceleration.x),
        @"y": @(acc.acceleration.y),
        @"z": @(acc.acceleration.z)
      };
      [self->_motionManager stopAccelerometerUpdates];
    } else if ([type isEqualToString:@"gyroscope"]) {
      CMGyroData *gyro = self->_motionManager.gyroData;
      data = @{
        @"x": @(gyro.rotationRate.x),
        @"y": @(gyro.rotationRate.y),
        @"z": @(gyro.rotationRate.z)
      };
      [self->_motionManager stopGyroUpdates];
    } else if ([type isEqualToString:@"magnetometer"]) {
      CMMagnetometerData *mag = self->_motionManager.magnetometerData;
      data = @{
        @"x": @(mag.magneticField.x),
        @"y": @(mag.magneticField.y),
        @"z": @(mag.magneticField.z)
      };
      [self->_motionManager stopMagnetometerUpdates];
    }
    resolve(data);
  });
}

@end

