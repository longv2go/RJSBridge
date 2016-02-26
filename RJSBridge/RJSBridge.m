//
//  RJSBridge.m
//  RJSBridge
//
//  Created by didi on 16/1/12.
//  Copyright © 2016年 didi. All rights reserved.
//

#import "RJSBridge.h"
#import "RJSDefines.h"
#import "RJSBridgeModule.h"
#import "RJSModuleData.h"
#import "RJSJSCExecutor.h"
#import "RJSConvert.h"
#import "RJSModuleMethod.h"
#import "RJSUtils.h"

#define RCTAssertJSThread() \
NSAssert(![NSStringFromClass([_javaScriptExecutor class]) isEqualToString:@"RCTJSCExecutor"] || \
[[[NSThread currentThread] name] isEqualToString:@"com.facebook.React.JavaScript"], \
@"This method must be called on JS thread")

/**
 * Must be kept in sync with `MessageQueue.js`.
 */
typedef NS_ENUM(NSUInteger, RCTBridgeFields) {
  RCTBridgeFieldRequestModuleIDs = 0,
  RCTBridgeFieldMethodIDs,
  RCTBridgeFieldParamss,
};

static NSMutableArray<Class> *RCTModuleClasses;
NSArray<Class> *RCTGetModuleClasses(void);
NSArray<Class> *RCTGetModuleClasses(void)
{
  return RCTModuleClasses;
}

/**
 * Register the given class as a bridge module. All modules must be registered
 * prior to the first bridge initialization.
 */
void RCTRegisterModule(Class);
void RCTRegisterModule(Class moduleClass)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    RCTModuleClasses = [NSMutableArray new];
  });
  
  assert([moduleClass conformsToProtocol:NSProtocolFromString(@"RJSBridgeModule")]);
  
  // Register module
  [RCTModuleClasses addObject:moduleClass];
}

NSString *RCTBridgeModuleNameForClass(Class cls)
{
  NSString *name = [cls moduleName];
  if (name.length == 0) {
    name = NSStringFromClass(cls);
  }
  return name;
}

@interface RJSBridge()

@property (nonatomic, strong) JSContext *context;
@property (nonatomic, strong) NSArray<RJSModuleData *> *moduleDataByID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RJSModuleData *> *moduleDataByName;
@property (nonatomic, strong) NSArray<Class> *moduleClassesByID;

@property (nonatomic, strong) RJSJSCExecutor *javaScriptExecutor;
@end

@implementation RJSBridge
{
  BOOL _wasBatchActive;
}

- (instancetype)initWithContext:(JSContext *)ctx
{
  if (self = [super init]) {
    _context = ctx;
    [self start];
  }
  return self;
}

- (void)start
{
  
  NSData *sourceCode = [RJSBridge loadSource];
  
  // Synchronously initialize all native modules that cannot be loaded lazily
  [self initModules];
  
  dispatch_queue_t bridgeQueue = dispatch_queue_create("com.facebook.react.RCTBridgeQueue", DISPATCH_QUEUE_CONCURRENT);
  dispatch_group_t initModulesAndLoadSource = dispatch_group_create();
  
  __weak RJSBridge *weakSelf = self;
  __block NSString *config;
  
  dispatch_group_enter(initModulesAndLoadSource);
  dispatch_async(bridgeQueue, ^{
    dispatch_group_t setupJSExecutorAndModuleConfig = dispatch_group_create();
    
    // Asynchronously initialize the JS executor
    dispatch_group_async(setupJSExecutorAndModuleConfig, bridgeQueue, ^{
      [weakSelf setUpExecutor];
    });
    
    // Asynchronously gather the module config
    dispatch_group_async(setupJSExecutorAndModuleConfig, bridgeQueue, ^{
//      if (weakSelf.isValid) {
        config = [weakSelf moduleConfig];
//      }
    });
    
    dispatch_group_notify(setupJSExecutorAndModuleConfig, bridgeQueue, ^{
      // We're not waiting for this to complete to leave dispatch group, since
      // injectJSONConfiguration and executeSourceCode will schedule operations
      // on the same queue anyway.
      [weakSelf injectJSONConfiguration:config onComplete:^(NSError *error) {
        if (error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            NSAssert(NO, @"");
          });
        }
      }];
      dispatch_group_leave(initModulesAndLoadSource);
    });
  });
  
  dispatch_group_notify(initModulesAndLoadSource, dispatch_get_main_queue(), ^{
    if (sourceCode) {
      dispatch_async(bridgeQueue, ^{
        [weakSelf executeSourceCode:sourceCode];
      });
    }
  });
}

- (void)executeSourceCode:(NSData *)sourceCode
{
  NSAssert(sourceCode, @"");
  [_javaScriptExecutor executeApplicationScript:sourceCode sourceURL:nil onComplete:^(NSError *error) {
    
  }];
}

- (void)injectJSONConfiguration:(NSString *)configJSON
                     onComplete:(void (^)(NSError *))onComplete
{
//  if (!self.valid) {
//    return;
//  }
  
  [_javaScriptExecutor injectJSONText:configJSON
                  asGlobalObjectNamed:@"__fbBatchedBridgeConfig"
                             callback:onComplete];
}

- (NSString *)moduleConfig
{
  NSMutableArray<NSArray *> *config = [NSMutableArray new];
  for (RJSModuleData *moduleData in _moduleDataByID) {
      [config addObject:@[moduleData.name]];
  }
  
  return RCTJSONStringify(@{
                            @"remoteModuleConfig": config,
                            }, NULL);
}

- (void)setUpExecutor
{
  [_javaScriptExecutor setUp];
}

- (void)initModules
{
  RJSAssertMainThread();
  
  NSMutableArray<RJSModuleData *> *moduleDataByID = [NSMutableArray new];
  NSMutableDictionary<NSString *, RJSModuleData *> *moduleDataByName = [NSMutableDictionary new];
  
  for (Class moduleClass in RCTGetModuleClasses()) {
    NSString *moduleName = RCTBridgeModuleNameForClass(moduleClass);
    id module = [[moduleClass alloc] init];
    
    RJSModuleData *moduleData;
    moduleData = [[RJSModuleData alloc] initWithModuleInstance:module
                                                        bridge:self];
    if (moduleData) {
      moduleDataByName[moduleName] = moduleData;
      [moduleDataByID addObject:moduleData];
    }
  }
  
  _moduleDataByID = [moduleDataByID copy];
  _moduleDataByName = [moduleDataByName copy];
  _moduleClassesByID = [moduleDataByID valueForKey:@"moduleClass"];
  
  // create executor
  _javaScriptExecutor = [[RJSJSCExecutor alloc] initWithContext:_context];
  [_javaScriptExecutor setBridge:self];

  for (RJSModuleData *moduleData in _moduleDataByID) {
    if (moduleData.hasInstance) {
      [moduleData methodQueue]; // initialize the queue
    }
  }
}

+ (NSData *)loadSource
{
  static NSData *source = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    source = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/RJSBridge.js", [[NSBundle mainBundle] bundlePath]]];
  });
  
  return source;
}


- (NSArray *)configForModuleName:(NSString *)moduleName
{
  RJSModuleData *moduleData = _moduleDataByName[moduleName];
  if (moduleData) {
    return moduleData.config;
  }
  return (id)kCFNull;
}


- (void)handleBuffer:(id)buffer batchEnded:(BOOL)batchEnded
{
  
  if (buffer != nil && buffer != (id)kCFNull) {
    _wasBatchActive = YES;
    [self handleBuffer:buffer];
    [self partialBatchDidFlush];
  }
}

- (void)handleBuffer:(NSArray *)buffer
{
  NSArray *requestsArray = [RJSConvert NSArray:buffer];
  if (RCT_DEBUG && requestsArray.count <= RCTBridgeFieldParamss) {
    NSLog(@"Buffer should contain at least %tu sub-arrays. Only found %tu",
                RCTBridgeFieldParamss + 1, requestsArray.count);
    return;
  }
  
  NSArray<NSNumber *> *moduleIDs = [RJSConvert NSNumberArray:requestsArray[RCTBridgeFieldRequestModuleIDs]];
  NSArray<NSNumber *> *methodIDs = [RJSConvert NSNumberArray:requestsArray[RCTBridgeFieldMethodIDs]];
  NSArray<NSArray *> *paramsArrays = [RJSConvert NSArrayArray:requestsArray[RCTBridgeFieldParamss]];
  
  if (RCT_DEBUG && (moduleIDs.count != methodIDs.count || moduleIDs.count != paramsArrays.count)) {
    NSLog(@"Invalid data message - all must be length: %zd", moduleIDs.count);
    return;
  }
  
  NSMapTable *buckets = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory
                                                  valueOptions:NSPointerFunctionsStrongMemory
                                                      capacity:_moduleDataByName.count];
  
  [moduleIDs enumerateObjectsUsingBlock:^(NSNumber *moduleID, NSUInteger i, __unused BOOL *stop) {
    RJSModuleData *moduleData = _moduleDataByID[moduleID.integerValue];
    dispatch_queue_t queue = moduleData.methodQueue;
    NSMutableOrderedSet<NSNumber *> *set = [buckets objectForKey:queue];
    if (!set) {
      set = [NSMutableOrderedSet new];
      [buckets setObject:set forKey:queue];
    }
    [set addObject:@(i)];
  }];
  
  for (dispatch_queue_t queue in buckets) {
    
    dispatch_block_t block = ^{
      NSOrderedSet *calls = [buckets objectForKey:queue];
      @autoreleasepool {
        for (NSNumber *indexObj in calls) {
          NSUInteger index = indexObj.unsignedIntegerValue;
          [self _handleRequestNumber:index
                            moduleID:[moduleIDs[index] integerValue]
                            methodID:[methodIDs[index] integerValue]
                              params:paramsArrays[index]];
        }
      }
      
    };
    
    if (queue) {
      dispatch_async(queue, block);
    } else {
      [_javaScriptExecutor executeBlockOnJavaScriptQueue:block];
    }
  }
}

- (void)partialBatchDidFlush
{
  for (RJSModuleData *moduleData in _moduleDataByID) {
    if (moduleData.implementsPartialBatchDidFlush) {
      [self dispatchBlock:^{
        [moduleData.instance partialBatchDidFlush];
      } queue:moduleData.methodQueue];
    }
  }
}


- (BOOL)_handleRequestNumber:(NSUInteger)i
                    moduleID:(NSUInteger)moduleID
                    methodID:(NSUInteger)methodID
                      params:(NSArray *)params
{
  if (RCT_DEBUG && ![params isKindOfClass:[NSArray class]]) {
    NSLog(@"Invalid module/method/params tuple for request #%zd", i);
    return NO;
  }
  
  RJSModuleData *moduleData = _moduleDataByID[moduleID];
  if (RCT_DEBUG && !moduleData) {
    NSLog(@"No module found for id '%zd'", moduleID);
    return NO;
  }
  
  id<RJSBridgeMethod> method = moduleData.methods[methodID];
  if (RCT_DEBUG && !method) {
    NSLog(@"Unknown methodID: %zd for module: %zd (%@)", methodID, moduleID, moduleData.name);
    return NO;
  }
  
  @try {
    [method invokeWithBridge:self module:moduleData.instance arguments:params];
  }
  @catch (NSException *exception) {
    // Pass on JS exceptions
    if ([exception.name hasPrefix:RCTFatalExceptionName]) {
      @throw exception;
    }
    
    NSString *message = [NSString stringWithFormat:
                         @"Exception '%@' was thrown while invoking %@ on target %@ with params %@",
                         exception, method.JSMethodName, moduleData.name, params];
  }
  
  return YES;
}

- (void)dispatchBlock:(dispatch_block_t)block
                queue:(dispatch_queue_t)queue
{
   if (queue) {
    dispatch_async(queue, block);
   } else {
     [_javaScriptExecutor executeBlockOnJavaScriptQueue:block];
   }
}

/**
 * Called by RCTModuleMethod from any thread.
 */
- (void)enqueueCallback:(NSNumber *)cbID args:(NSArray *)args
{
  /**
   * AnyThread
   */
  
  __weak RJSBridge *weakSelf = self;
  [_javaScriptExecutor executeBlockOnJavaScriptQueue:^{
    
    RJSBridge *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    
    // TODO: 如果在loading过程中执行callback
    
//    if (strongSelf.loading) {
//      dispatch_block_t pendingCall = ^{
//        [weakSelf _actuallyInvokeCallback:cbID arguments:args ?: @[]];
//      };
//      [strongSelf->_pendingCalls addObject:pendingCall];
//    } else {
      [strongSelf _actuallyInvokeCallback:cbID arguments:args];
//    }
  }];
}

- (void)_actuallyInvokeCallback:(NSNumber *)cbID
                      arguments:(NSArray *)args
{
  RCTJavaScriptCallback processResponse = ^(id json, NSError *error) {
    NSAssert(!error, @"");
    
//    if (!self.isValid) {
//      return;
//    }
    [self handleBuffer:json batchEnded:YES];
  };
  
  [_javaScriptExecutor invokeCallbackID:cbID
                              arguments:args
                               callback:processResponse];
}

+ (BOOL)isContextBridged:(JSContext *)context
{
  JSValue *rjs = context[@"_rjs"]; // This name should sync with that define in RJSBridge.js
  if (rjs) {
    return !rjs.isUndefined;
  }
  return NO;
}

@end
