/**
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import "RJSBridgeModule.h"

@protocol RJSBridgeMethod;
@class RJSBridge;

@interface RJSModuleData : NSObject

- (instancetype)initWithModuleInstance:(id<RJSBridgeModule>)instance
                                bridge:(RJSBridge *)bridge;


@property (nonatomic, strong, readonly) Class moduleClass;
@property (nonatomic, copy, readonly) NSString *name;

/**
 * Returns the module methods. Note that this will gather the methods the first
 * time it is called and then memoize the results.
 */
@property (nonatomic, copy, readonly) NSArray<id<RJSBridgeMethod>> *methods;

/**
 * Returns YES if module instance has already been initialized; NO otherwise.
 */
@property (nonatomic, assign, readonly) BOOL hasInstance;

/**
 * Returns the current module instance. Note that this will init the instance
 * if it has not already been created. To check if the module instance exists
 * without causing it to be created, use `hasInstance` instead.
 */
@property (nonatomic, strong, readonly) id<RJSBridgeModule> instance;

/**
 * Returns the module method dispatch queue. Note that this will init both the
 * queue and the module itself if they have not already been created.
 */
@property (nonatomic, strong, readonly) dispatch_queue_t methodQueue;

/**
 * Returns the module config. Note that this will init the module if it has
 * not already been created. This method can be called on any thread, but will
 * block the main thread briefly if the module implements `constantsToExport`.
 */
@property (nonatomic, copy, readonly) NSArray *config;

/**
 * Whether the receiver has a valid `instance` which implements -batchDidComplete.
 */
@property (nonatomic, assign, readonly) BOOL implementsBatchDidComplete;

/**
 * Whether the receiver has a valid `instance` which implements
 * -partialBatchDidFlush.
 */
@property (nonatomic, assign, readonly) BOOL implementsPartialBatchDidFlush;

@end
