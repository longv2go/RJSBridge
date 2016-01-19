//
//  ViewController.m
//  RJSBridge
//
//  Created by didi on 16/1/12.
//  Copyright © 2016年 didi. All rights reserved.
//

#import "ViewController.h"
#import "RJSBridge.h"

@interface ViewController ()<UIWebViewDelegate>
@property(nonatomic, strong) UIWebView *webView;
@property(nonatomic, strong) RJSBridge *bridge;
@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
  _webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
  _webView.delegate = self;
  [self.view addSubview:_webView];
//  [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8000/test.html"]]];
  
  [_webView loadHTMLString:[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/test.html",[NSBundle mainBundle].bundlePath]] baseURL:nil];
  
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  _bridge = [[RJSBridge alloc] initWithContext:[webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"]];
}

@end
