RJSBridge
------

RJSBridge 是把react-native(iOS)中的Javascript和Objective-C互相通信的部分剥离出来的 
一个单独的库。其中大部分代码均来自react-native，我把类前缀改为了RJS，但是类结构几乎没有改变。可以用此repo来作为研究react-native 通信部分的简化版本。
RJSBridge.js的代码主要来自MessageQueue.js, BatchedBridge.js和NativeModules.js。
使用方法和react-native相同，详见 [Native Modules](https://facebook.github.io/react-native/docs/native-modules-ios.html#content)

#暴漏本地类给JS

暴漏一个类，需要引入RJSBridgeModule协议，代码如下
```objc
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
```

调用
```javascript
_rjs.ExportModule.hello('this is test');
```

