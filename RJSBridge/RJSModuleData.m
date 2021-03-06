

#import "RJSModuleData.h"

#import "RJSBridge.h"
#import "RJSModuleMethod.h"
#import "RJSUtils.h"

#import <objc/runtime.h>

void RCTExecuteOnMainThread(dispatch_block_t block, BOOL sync)
{
    if ([NSThread isMainThread]) {
        block();
    } else if (sync) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            block();
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
}

@implementation RJSModuleData
{
  NSString *_queueName;
  __weak RJSBridge *_bridge;
  NSLock *_instanceLock;
  BOOL _setupComplete;
}

@synthesize methods = _methods;
@synthesize instance = _instance;
@synthesize methodQueue = _methodQueue;

- (instancetype)initWithModuleClass:(Class)moduleClass
                             bridge:(RJSBridge *)bridge
{
  if ((self = [super init])) {
    _moduleClass = moduleClass;
    _bridge = bridge;

    _implementsBatchDidComplete = [_moduleClass instancesRespondToSelector:@selector(batchDidComplete)];
    _implementsPartialBatchDidFlush = [_moduleClass instancesRespondToSelector:@selector(partialBatchDidFlush)];

    _instanceLock = [NSLock new];
  }
  return self;
}

- (instancetype)initWithModuleInstance:(id<RJSBridgeModule>)instance
                                bridge:(RJSBridge *)bridge
{
  if ((self = [self initWithModuleClass:[instance class] bridge:bridge])) {
    _instance = instance;
  }
  return self;
}

#pragma mark - private setup methods

- (void)setBridgeForInstance
{
  NSAssert(_instance, @"setBridgeForInstance called before %@ initialized", self.name);
  if ([_instance respondsToSelector:@selector(bridge)] && !_instance.bridge) {
    @try {
      [(id)_instance setValue:_bridge forKey:@"bridge"];
    }
    @catch (NSException *exception) {
      NSLog(@"%@ has no setter or ivar for its bridge, which is not "
                  "permitted. You must either @synthesize the bridge property, "
                  "or provide your own setter method.", self.name);
    }
  }
}

- (void)setUpMethodQueue
{
  if (!_methodQueue) {
    NSAssert(_instance, @"setUpMethodQueue called before initialized");
    BOOL implementsMethodQueue = [_instance respondsToSelector:@selector(methodQueue)];
    if (implementsMethodQueue) {
      _methodQueue = _instance.methodQueue;
    }
    if (!_methodQueue) {

      // Create new queue (store queueName, as it isn't retained by dispatch_queue)
      _queueName = [NSString stringWithFormat:@"com.facebook.React.%@Queue", self.name];
      _methodQueue = dispatch_queue_create(_queueName.UTF8String, DISPATCH_QUEUE_SERIAL);

      // assign it to the module
      if (implementsMethodQueue) {
        @try {
          [(id)_instance setValue:_methodQueue forKey:@"methodQueue"];
        }
        @catch (NSException *exception) {
            
            // TODO:
            NSLog(@"%@ is returning nil for it's methodQueue, which is not "
                      "permitted. You must either return a pre-initialized "
                      "queue, or @synthesize the methodQueue to let the bridge "
                      "create a queue for you.", self.name);
        }
      }
    }

    // Needs to be sent after bridge has been set for all module instances.
    // Makes sense to put it here, since the same rules apply for methodQueue.
//    [[NSNotificationCenter defaultCenter]
//     postNotificationName:RCTDidInitializeModuleNotification
//     object:_bridge userInfo:@{@"module": _instance}];
  }
}

#pragma mark - public getters

- (BOOL)hasInstance
{
  return _instance != nil;
}

- (id<RJSBridgeModule>)instance
{
  [_instanceLock lock];
  if (!_setupComplete) {
    if (!_instance) {
      _instance = [_moduleClass new];
    }
    // Bridge must be set before methodQueue is set up, as methodQueue
    // initialization requires it (View Managers get their queue by calling
    // self.bridge.uiManager.methodQueue)
    [self setBridgeForInstance];
    [self setUpMethodQueue];
    _setupComplete = YES;
  }
  [_instanceLock unlock];
  return _instance;
}

- (NSString *)name
{
  return RCTBridgeModuleNameForClass(_moduleClass);
}

- (NSArray<id<RJSBridgeMethod>> *)methods
{
  if (!_methods) {
    NSMutableArray<id<RJSBridgeMethod>> *moduleMethods = [NSMutableArray new];

    if ([_moduleClass instancesRespondToSelector:@selector(methodsToExport)]) {
      [self instance];
      [moduleMethods addObjectsFromArray:[_instance methodsToExport]];
    }

    unsigned int methodCount;
    Method *methods = class_copyMethodList(object_getClass(_moduleClass), &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {
      Method method = methods[i];
      SEL selector = method_getName(method);
      if ([NSStringFromSelector(selector) hasPrefix:@"__rct_export__"]) {
        IMP imp = method_getImplementation(method);
        NSArray<NSString *> *entries =
          ((NSArray<NSString *> *(*)(id, SEL))imp)(_moduleClass, selector);
        id<RJSBridgeMethod> moduleMethod =
          [[RJSModuleMethod alloc] initWithMethodSignature:entries[1]
                                              JSMethodName:entries[0]
                                               moduleClass:_moduleClass];

        [moduleMethods addObject:moduleMethod];
      }
    }

    free(methods);

    _methods = [moduleMethods copy];
  }
  return _methods;
}

- (NSArray *)config
{
  __block NSDictionary<NSString *, id> *constants;
  if (RCTClassOverridesInstanceMethod(_moduleClass, @selector(constantsToExport))) {
    [self instance];
    RCTExecuteOnMainThread(^{
      constants = [_instance constantsToExport];
    }, YES);
  }

  if (constants.count == 0 && self.methods.count == 0) {
    return (id)kCFNull; // Nothing to export
  }

  NSMutableArray<NSString *> *methods = self.methods.count ? [NSMutableArray new] : nil;
  NSMutableArray<NSNumber *> *asyncMethods = nil;
  for (id<RJSBridgeMethod> method in self.methods) {
    if (method.functionType == RCTFunctionTypePromise) {
      if (!asyncMethods) {
        asyncMethods = [NSMutableArray new];
      }
      [asyncMethods addObject:@(methods.count)];
    }
    [methods addObject:method.JSMethodName];
  }

  NSMutableArray *config = [NSMutableArray new];
  [config addObject:self.name];
  if (constants.count) {
    [config addObject:constants];
  }
  if (methods) {
    [config addObject:methods];
    if (asyncMethods) {
      [config addObject:asyncMethods];
    }
  }
  return config;
}

- (dispatch_queue_t)methodQueue
{
  [self instance];
  return _methodQueue;
}

- (void)invalidate
{
  _methodQueue = nil;
}

@end
