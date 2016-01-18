//
//  ExportModule.m
//  RJSBridge
//
//  Created by didi on 16/1/18.
//  Copyright © 2016年 didi. All rights reserved.
//

#import "ExportModule.h"
#import "RJSBridge.h"

@implementation ExportModule
RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(hello:(NSString *)world)
{
  NSLog(@"--- %@", world);
}

@end
