/**
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import "RJSBridgeMethod.h"

@class RJSBridge;

@interface RCTMethodArgument : NSObject

@property (nonatomic, copy, readonly) NSString *type;
@property (nonatomic, readonly) RCTNullability nullability;
@property (nonatomic, readonly) BOOL unused;

@end

@interface RJSModuleMethod : NSObject <RJSBridgeMethod>

@property (nonatomic, readonly) Class moduleClass;
@property (nonatomic, readonly) SEL selector;

- (instancetype)initWithMethodSignature:(NSString *)objCMethodName
                          JSMethodName:(NSString *)JSMethodName
                           moduleClass:(Class)moduleClass NS_DESIGNATED_INITIALIZER;

- (void)invokeWithBridge:(RJSBridge *)bridge
                  module:(id)module
               arguments:(NSArray *)arguments;

@end
