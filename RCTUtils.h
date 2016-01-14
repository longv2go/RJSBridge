/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <tgmath.h>

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "RCTDefines.h"

extern NSString *const RCTErrorDomain;
extern NSString *const RCTFatalExceptionName;


// JSON serialization/deserialization
RCT_EXTERN NSString *RCTJSONStringify(id jsonObject, NSError **error);
RCT_EXTERN id RCTJSONParse(NSString *jsonString, NSError **error);
RCT_EXTERN id RCTJSONParseMutable(NSString *jsonString, NSError **error);


// Execute the specified block on the main thread. Unlike dispatch_sync/async
// this will not context-switch if we're already running on the main thread.
RCT_EXTERN void RCTExecuteOnMainThread(dispatch_block_t block, BOOL sync);

// Module subclass support
RCT_EXTERN BOOL RCTClassOverridesClassMethod(Class cls, SEL selector);
RCT_EXTERN BOOL RCTClassOverridesInstanceMethod(Class cls, SEL selector);

// Creates a standardized error object
RCT_EXTERN NSDictionary<NSString *, id> *RCTMakeError(NSString *message, id toStringify, NSDictionary<NSString *, id> *extraData);
RCT_EXTERN NSDictionary<NSString *, id> *RCTMakeAndLogError(NSString *message, id toStringify, NSDictionary<NSString *, id> *extraData);
RCT_EXTERN NSDictionary<NSString *, id> *RCTJSErrorFromNSError(NSError *error);

// Create an NSError in the RCTErrorDomain
RCT_EXTERN NSError *RCTErrorWithMessage(NSString *message);

// Convert nil values to NSNull, and vice-versa
RCT_EXTERN id RCTNilIfNull(id value);
RCT_EXTERN id RCTNullIfNil(id value);
