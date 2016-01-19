/**
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class RJSBridge;

typedef NS_ENUM(NSUInteger, RCTNullability) {
    RCTNullabilityUnspecified,
    RCTNullable,
    RCTNonnullable,
};

typedef NS_ENUM(NSUInteger, RCTFunctionType) {
  RCTFunctionTypeNormal,
  RCTFunctionTypePromise,
};

@protocol RCTBridgeMethod <NSObject>

@property (nonatomic, copy, readonly) NSString *JSMethodName;
@property (nonatomic, copy, readonly) NSDictionary *profileArgs;
@property (nonatomic, readonly) RCTFunctionType functionType;

- (void)invokeWithBridge:(RJSBridge *)bridge
                  module:(id)module
               arguments:(NSArray *)arguments;

@end
