//
//  RJSBridge.h
//  RJSBridge
//
//  Created by didi on 16/1/12.
//  Copyright © 2016年 didi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NSString *RCTBridgeModuleNameForClass(Class cls);

@interface RJSBridge : NSObject

- (instancetype)initWithContext:(JSContext *)ctx;

/**
 * This method is used to invoke a callback that was registered in the
 * JavaScript application context. Safe to call from any thread.
 */
- (void)enqueueCallback:(NSNumber *)cbID args:(NSArray *)args;

/**
 * Exposed for the RCTJSCExecutor for lazily loading native modules
 */
- (NSArray *)configForModuleName:(NSString *)moduleName;

/**
 * Executes native calls sent by JavaScript. Exposed for testing purposes only
 */
- (void)handleBuffer:(NSArray<NSArray *> *)buffer;

/**
 * Exposed for the RCTJSCExecutor for sending native methods called from
 * JavaScript in the middle of a batch.
 */
- (void)handleBuffer:(NSArray<NSArray *> *)buffer batchEnded:(BOOL)hasEnded;

@end
