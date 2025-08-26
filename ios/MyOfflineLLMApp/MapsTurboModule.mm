#import <React/RCTBridgeModule.h>
#import <MapKit/MapKit.h>

@interface RCT_EXTERN_MODULE(MapsTurboModule, NSObject)

RCT_EXTERN_METHOD(showMap:(double)latitude longitude:(double)longitude title:(NSString *)title)

RCT_EXTERN_METHOD(getDirections:(NSString *)from to:(NSString *)to mode:(NSString *)mode resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(searchPlaces:(NSString *)query near:(NSString *)near resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end

@implementation MapsTurboModule

RCT_EXPORT_METHOD(showMap:(double)latitude longitude:(double)longitude title:(NSString *)title) {
  MKMapItem *mapItem = [[MKMapItem alloc] init];
  mapItem.placemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];
  mapItem.name = title;
  [mapItem openInMapsWithLaunchOptions:nil];
}

RCT_EXPORT_METHOD(getDirections:(NSString *)from to:(NSString *)to mode:(NSString *)mode resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
  MKPlacemark *fromPlacemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(0, 0)];
  request.source = [[MKMapItem alloc] initWithPlacemark:fromPlacemark];
  MKPlacemark *toPlacemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(0, 0)];
  request.destination = [[MKMapItem alloc] initWithPlacemark:toPlacemark];
  if ([mode isEqualToString:@"walking"]) request.transportType = MKDirectionsTransportTypeWalking;
  else if ([mode isEqualToString:@"transit"]) request.transportType = MKDirectionsTransportTypeTransit;
  else request.transportType = MKDirectionsTransportTypeAutomobile;
  MKDirections *directions = [[MKDirections alloc] initWithRequest:request];
  [directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse *response, NSError *error) {
    if (error) {
      reject(@"directions_error", error.localizedDescription, error);
      return;
    }
    NSMutableArray *routes = [NSMutableArray array];
    for (MKRoute *route in response.routes) {
      [routes addObject:@{
        @"distance": @(route.distance),
        @"expectedTime": @(route.expectedTravelTime),
        @"steps": @[]
      }];
    }
    resolve(routes);
  }];
}

RCT_EXPORT_METHOD(searchPlaces:(NSString *)query near:(NSString *)near resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
  request.naturalLanguageQuery = query;
  if (near) {
    request.region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(0, 0), MKCoordinateSpanMake(0.1, 0.1));
  }
  MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
  [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
    if (error) {
      reject(@"search_error", error.localizedDescription, error);
      return;
    }
    NSMutableArray *places = [NSMutableArray array];
    for (MKMapItem *item in response.mapItems) {
      [places addObject:@{
        @"name": item.name,
        @"latitude": @(item.placemark.coordinate.latitude),
        @"longitude": @(item.placemark.coordinate.longitude)
      }];
    }
    resolve(places);
  }];
}

@end

