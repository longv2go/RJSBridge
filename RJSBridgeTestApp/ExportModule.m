//
//  ExportModule.m
//  RJSBridge
//
//  Created by didi on 16/1/18.
//  Copyright © 2016年 didi. All rights reserved.
//

#import "ExportModule.h"
#import "RJSBridge.h"

@interface ExportModule()<RJSBridgeModule>

@end

@implementation ExportModule
RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(hello:(NSString *)world)
{
  NSLog(@"--- %@", world);
}

RCT_EXPORT_METHOD(call:(NSString *)hi back:(RCTResponseSenderBlock)back)
{
  NSLog(@"-------- ");
  back(@[[NSString stringWithFormat:@"%@, who are you?", hi], @"second"]);
}

@end
