
#import "RJSUtils.h"
#include <objc/runtime.h>

NSString *const RCTErrorDomain = @"RCTErrorDomain";
NSString *const RCTFatalExceptionName = @"RCTFatalException";


NSString *RCTJSONStringify(id jsonObject, NSError **error)
{
  static SEL JSONKitSelector = NULL;
  static NSSet<Class> *collectionTypes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    SEL selector = NSSelectorFromString(@"JSONStringWithOptions:error:");
    if ([NSDictionary instancesRespondToSelector:selector]) {
      JSONKitSelector = selector;
      collectionTypes = [NSSet setWithObjects:
                         [NSArray class], [NSMutableArray class],
                         [NSDictionary class], [NSMutableDictionary class], nil];
    }
  });
  
  // Use JSONKit if available and object is not a fragment
  if (JSONKitSelector && [collectionTypes containsObject:[jsonObject classForCoder]]) {
    return ((NSString *(*)(id, SEL, int, NSError **))objc_msgSend)(jsonObject, JSONKitSelector, 0, error);
  }
  
  // Use Foundation JSON method
  NSData *jsonData = [NSJSONSerialization
                      dataWithJSONObject:jsonObject
                      options:(NSJSONWritingOptions)NSJSONReadingAllowFragments
                      error:error];
  return jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : nil;
}

BOOL RCTClassOverridesInstanceMethod(Class cls, SEL selector)
{
  unsigned int numberOfMethods;
  Method *methods = class_copyMethodList(cls, &numberOfMethods);
  for (unsigned int i = 0; i < numberOfMethods; i++) {
    if (method_getName(methods[i]) == selector) {
      free(methods);
      return YES;
    }
  }
  free(methods);
  return NO;
}

id RCTNilIfNull(id value)
{
  return value == (id)kCFNull ? nil : value;
}

double RCTZeroIfNaN(double value)
{
  return isnan(value) || isinf(value) ? 0 : value;
}

NSDictionary<NSString *, id> *RCTMakeError(NSString *message, id toStringify, NSDictionary<NSString *, id> *extraData)
{
  if (toStringify) {
    message = [message stringByAppendingString:[toStringify description]];
  }
  
  NSMutableDictionary<NSString *, id> *error = [NSMutableDictionary dictionaryWithDictionary:extraData];
  error[@"message"] = message;
  return error;
}

NSDictionary<NSString *, id> *RCTJSErrorFromNSError(NSError *error)
{
  NSString *errorMessage;
  NSArray<NSString *> *stackTrace = [NSThread callStackSymbols];
  NSMutableDictionary<NSString *, id> *errorInfo =
  [NSMutableDictionary dictionaryWithObject:stackTrace forKey:@"nativeStackIOS"];
  
  if (error) {
    errorMessage = error.localizedDescription ?: @"Unknown error from a native module";
    errorInfo[@"domain"] = error.domain ?: RCTErrorDomain;
    errorInfo[@"code"] = @(error.code);
  } else {
    errorMessage = @"Unknown error from a native module";
    errorInfo[@"domain"] = RCTErrorDomain;
    errorInfo[@"code"] = @-1;
  }
  
  return RCTMakeError(errorMessage, nil, errorInfo);
}

NSError *RCTErrorWithMessage(NSString *message)
{
  NSDictionary<NSString *, id> *errorInfo = @{NSLocalizedDescriptionKey: message};
  return [[NSError alloc] initWithDomain:RCTErrorDomain code:0 userInfo:errorInfo];
}

static id _RCTJSONParse(NSString *jsonString, BOOL mutable, NSError **error)
{
  if (jsonString) {
    
    // Use Foundation JSON method
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) {
      jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
      if (jsonData) {
        NSLog(@"RCTJSONParse received the following string, which could "
                   "not be losslessly converted to UTF8 data: '%@'", jsonString);
      } else {
        NSString *errorMessage = @"RCTJSONParse received invalid UTF8 data";
        if (error) {
          *error = RCTErrorWithMessage(errorMessage);
        } else {
          NSLog(@"%@", errorMessage);
        }
        return nil;
      }
    }
    NSJSONReadingOptions options = NSJSONReadingAllowFragments;
    if (mutable) {
      options |= NSJSONReadingMutableContainers;
    }
    return [NSJSONSerialization JSONObjectWithData:jsonData
                                           options:options
                                             error:error];
  }
  return nil;
}

id RCTJSONParse(NSString *jsonString, NSError **error)
{
  return _RCTJSONParse(jsonString, NO, error);
}
