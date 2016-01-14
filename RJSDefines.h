//
//  RJSDefines.h
//  RJSBridge
//
//  Created by didi on 16/1/12.
//  Copyright © 2016年 didi. All rights reserved.
//

#ifndef RJSDefines_h
#define RJSDefines_h

#define RJSAssertMainThread() NSAssert([NSThread isMainThread], \
@"This function must be called on the main thread")

#endif /* RJSDefines_h */
