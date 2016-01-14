//
//  RJSBridge.m
//  RJSBridge
//
//  Created by didi on 16/1/12.
//  Copyright © 2016年 didi. All rights reserved.
//

#import "RJSBridge.h"
#import "RJSDefines.h"
#import "RCTBridgeModule.h"
#import "RCTModuleData.h"
#import "RCTJSCExecutor.h"
#import "RCTConvert.h"
#import "RCTModuleMethod.h"
#import "RCTUtils.h"

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
  
  assert([moduleClass conformsToProtocol:NSProtocolFromString(@"RCTBridgeModule")]);
  
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
@property (nonatomic, strong) NSArray<RCTModuleData *> *moduleDataByID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RCTModuleData *> *moduleDataByName;
@property (nonatomic, strong) NSArray<Class> *moduleClassesByID;

@property (nonatomic, weak) RCTJSCExecutor *javaScriptExecutor;
@end

@implementation RJSBridge
{
  BOOL _wasBatchActive;
}

- (instancetype)initWithContext:(JSContext *)ctx
{
  if (self = [super init]) {
    _context = ctx;
    [self setup];
  }
  return self;
}

- (void)setup
{
  // Synchronously initialize all native modules that cannot be loaded lazily
  [self initModules];
}

- (void)initModules
{
  RJSAssertMainThread();
  
  NSMutableArray<RCTModuleData *> *moduleDataByID = [NSMutableArray new];
  NSMutableDictionary<NSString *, RCTModuleData *> *moduleDataByName = [NSMutableDictionary new];
  
  for (Class moduleClass in RCTGetModuleClasses()) {
    NSString *moduleName = RCTBridgeModuleNameForClass(moduleClass);
    id module = [[moduleClass alloc] init];
    
    RCTModuleData *moduleData;
    moduleData = [[RCTModuleData alloc] initWithModuleInstance:module
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


}

+ (NSString *)loadSource
{
  static NSString *source = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    source = nil;// TODO:
  });
  
  return source;
}


- (NSArray *)configForModuleName:(NSString *)moduleName
{
  RCTModuleData *moduleData = _moduleDataByName[moduleName];
  if (moduleData) {
    return moduleData.config;
  }
  return (id)kCFNull;
}


- (void)handleBuffer:(id)buffer batchEnded:(BOOL)batchEnded
{
  RCTAssertJSThread();
  
  if (buffer != nil && buffer != (id)kCFNull) {
    _wasBatchActive = YES;
    [self handleBuffer:buffer];
    [self partialBatchDidFlush];
  }
}

- (void)handleBuffer:(NSArray *)buffer
{
  NSArray *requestsArray = [RCTConvert NSArray:buffer];
  if (RCT_DEBUG && requestsArray.count <= RCTBridgeFieldParamss) {
    NSLog(@"Buffer should contain at least %tu sub-arrays. Only found %tu",
                RCTBridgeFieldParamss + 1, requestsArray.count);
    return;
  }
  
  NSArray<NSNumber *> *moduleIDs = [RCTConvert NSNumberArray:requestsArray[RCTBridgeFieldRequestModuleIDs]];
  NSArray<NSNumber *> *methodIDs = [RCTConvert NSNumberArray:requestsArray[RCTBridgeFieldMethodIDs]];
  NSArray<NSArray *> *paramsArrays = [RCTConvert NSArrayArray:requestsArray[RCTBridgeFieldParamss]];
  
  if (RCT_DEBUG && (moduleIDs.count != methodIDs.count || moduleIDs.count != paramsArrays.count)) {
    NSLog(@"Invalid data message - all must be length: %zd", moduleIDs.count);
    return;
  }
  
  NSMapTable *buckets = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory
                                                  valueOptions:NSPointerFunctionsStrongMemory
                                                      capacity:_moduleDataByName.count];
  
  [moduleIDs enumerateObjectsUsingBlock:^(NSNumber *moduleID, NSUInteger i, __unused BOOL *stop) {
    RCTModuleData *moduleData = _moduleDataByID[moduleID.integerValue];
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
  for (RCTModuleData *moduleData in _moduleDataByID) {
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
  
  RCTModuleData *moduleData = _moduleDataByID[moduleID];
  if (RCT_DEBUG && !moduleData) {
    NSLog(@"No module found for id '%zd'", moduleID);
    return NO;
  }
  
  id<RCTBridgeMethod> method = moduleData.methods[methodID];
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

@end
