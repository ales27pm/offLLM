#import "React/RCTBridgeModule.h"
#import <Contacts/Contacts.h>

@interface ContactsTurboModule : NSObject <RCTBridgeModule>
@end

@implementation ContactsTurboModule

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(findContact:(NSString *)query resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  CNContactStore *store = [[CNContactStore alloc] init];
  [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError *error) {
    if (!granted) {
      reject(@"permission_denied", @"Contacts access denied", error);
      return;
    }
    NSPredicate *predicate = [CNContact predicateForContactsMatchingName:query];
    NSArray *keys = @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey];
    NSArray *contacts = [store unifiedContactsMatchingPredicate:predicate keysToFetch:keys error:&error];
    if (error) {
      reject(@"search_error", error.localizedDescription, error);
      return;
    }
    NSMutableArray *result = [NSMutableArray array];
    for (CNContact *contact in contacts) {
      NSMutableArray *phones = [NSMutableArray array];
      for (CNLabeledValue *phone in contact.phoneNumbers) {
        [phones addObject:((CNPhoneNumber *)phone.value).stringValue];
      }
      NSMutableArray *emails = [NSMutableArray array];
      for (CNLabeledValue *email in contact.emailAddresses) {
        [emails addObject:email.value];
      }
      [result addObject:@{
        @"name": [NSString stringWithFormat:@"%@ %@", contact.givenName, contact.familyName],
        @"phones": phones,
        @"emails": emails
      }];
    }
    resolve(result);
  }];
}

RCT_EXPORT_METHOD(addContact:(NSString *)name phone:(NSString *)phone email:(NSString *)email resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  CNContactStore *store = [[CNContactStore alloc] init];
  [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError *error) {
    if (!granted) {
      reject(@"permission_denied", @"Contacts access denied", error);
      return;
    }
    CNMutableContact *contact = [[CNMutableContact alloc] init];
    // Improved name parsing: handle given, middle, and family names
    NSString *givenName = @"";
    NSString *middleName = @"";
    NSString *familyName = @"";

    NSArray *nameParts = [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    nameParts = [nameParts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];

    if ([nameParts count] == 1) {
      givenName = nameParts[0];
    } else if ([nameParts count] == 2) {
      givenName = nameParts[0];
      familyName = nameParts[1];
    } else if ([nameParts count] > 2) {
      givenName = nameParts[0];
      familyName = nameParts.lastObject;
      NSRange middleRange = NSMakeRange(1, nameParts.count - 2);
      middleName = [[nameParts subarrayWithRange:middleRange] componentsJoinedByString:@" "];
    }

    contact.givenName = givenName;
    contact.middleName = middleName;
    contact.familyName = familyName;
    if (phone) {
      CNPhoneNumber *phoneNumber = [CNPhoneNumber phoneNumberWithStringValue:phone];
      contact.phoneNumbers = @[[CNLabeledValue labeledValueWithLabel:CNLabelPhoneNumberMobile value:phoneNumber]];
    }
    if (email) {
      contact.emailAddresses = @[[CNLabeledValue labeledValueWithLabel:CNLabelHome value:email]];
    }
    CNSaveRequest *request = [[CNSaveRequest alloc] init];
    [request addContact:contact toContainerWithIdentifier:nil];
    [store executeSaveRequest:request error:&error];
    if (error) {
      reject(@"save_error", error.localizedDescription, error);
    } else {
      resolve(@{ @"success": @YES });
    }
  }];
}

@end

