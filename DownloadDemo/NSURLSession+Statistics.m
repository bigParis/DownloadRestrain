//
//  NSURLSession+Statistics.m
//  DownloadDemo
//
//  Created by yy on 2019/3/23.
//  Copyright © 2019年 BP. All rights reserved.
//

#import "NSURLSession+Statistics.h"
#import <objc/runtime.h>

static BOOL hasDidFinishCollectingMetrics;

@interface NSURLSession ()<NSURLSessionDataDelegate>

@end

@implementation NSURLSession (Statistics)

+ (void)load
{
    SEL originalSelector = @selector(initWithConfiguration:delegate:delegateQueue:);
    SEL swizzledSelector = @selector(my_initWithConfiguration:delegate:delegateQueue:);
    Method originalMethod = class_getInstanceMethod([self class], originalSelector);
    Method swizzledMethod = class_getInstanceMethod([self class], swizzledSelector);

    BOOL didAddMethod =
    class_addMethod([self class],
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod([NSURLSession class],
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (NSURLSession *)my_initWithConfiguration:(NSURLSessionConfiguration *)configuration delegate: (id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL originalSelector = @selector(URLSession:task:didFinishCollectingMetrics:);
        SEL swizzledSelector = @selector(my_URLSession:task:didFinishCollectingMetrics:);
        Method originalMethod = class_getInstanceMethod([delegate class], originalSelector);
        Method swizzledMethod = class_getInstanceMethod([self class], swizzledSelector);
        // 对于每个实例都要计算一次， 但添加方法只执行一次， 而且其他方法也要使用，所以使用全局静态变量
        hasDidFinishCollectingMetrics = originalMethod != nil;
        if (!originalMethod) {
            // 如果delegate类不存在这个方法，添加一个
            Method exchangeMethod = class_getInstanceMethod([self class], swizzledSelector);
            class_addMethod([delegate class], originalSelector, class_getMethodImplementation([self class], swizzledSelector), method_getTypeEncoding(exchangeMethod));
        }
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
    
    return [self my_initWithConfiguration:configuration delegate:delegate delegateQueue:queue];
}

- (void)my_URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    // 调到这里传进来的self实际是session的delegate, 那怎么拿到原来的self, 实际就是session。
    NSLog(@"taskInterval:%@, redirectCount:%@, metrics.transactionMetrics.count:%@", metrics.taskInterval, @(metrics.redirectCount), @(metrics.transactionMetrics.count));
    for (int i = 0; i < metrics.transactionMetrics.count; ++i) {
        NSURLSessionTaskTransactionMetrics *metric = metrics.transactionMetrics[i];
        NSLog(@"networkProtocolName:%@, proxyConnection:%@, reusedConnection:%@, resourceFetchType:%@", metric.networkProtocolName, @(metric.proxyConnection), @(metric.reusedConnection), @(metric.resourceFetchType));
        NSTimeInterval lookupTime = [metric.domainLookupEndDate timeIntervalSinceDate:metric.domainLookupStartDate];
        NSTimeInterval connectTime = [metric.connectEndDate timeIntervalSinceDate:metric.connectStartDate];
        NSTimeInterval secConnectTime = [metric.secureConnectionEndDate timeIntervalSinceDate:metric.secureConnectionStartDate];
        NSTimeInterval requestTime = [metric.requestEndDate timeIntervalSinceDate:metric.requestEndDate];
        NSTimeInterval responseTime = [metric.responseEndDate timeIntervalSinceDate:metric.responseStartDate];
        NSLog(@"域名解析时间:%@ms\n 建立连接时间:%@ms 建立安全连接耗时:%@ms, 请求耗时:%@ms, 响应耗时:%@ms", @(lookupTime), @(connectTime), @(secConnectTime), @(requestTime), @(responseTime));
    }

    if (hasDidFinishCollectingMetrics) {
        [session my_URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}
@end
