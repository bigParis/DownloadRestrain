//
//  NetworkStateOrRSSI.m
//  GHZeusLibraries
//
//  Created by 张冠华 on 16/4/28.
//  Copyright © 2016年 张冠华. All rights reserved.
//

#import "NSObject+NetworkStateOrRSSI.h"
#include <ifaddrs.h>
#include <sys/socket.h>
#include <net/if.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSObject (bytes)
@property (assign,nonatomic) uint32_t historyIBytes;
@property (assign,nonatomic) uint32_t historyOBytes;
@property (assign,nonatomic) uint32_t oldIBytes;
@property (assign,nonatomic) uint32_t oldOBytes;
@property (assign,nonatomic) BOOL     isFirst;
@end

@implementation NSObject (bytes)

- (void)setHistoryIBytes:(uint32_t)historyIBytes
{
    objc_setAssociatedObject(self, @selector(historyIBytes), [NSNumber numberWithInt:historyIBytes], OBJC_ASSOCIATION_ASSIGN);
}

- (uint32_t)historyIBytes
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}

- (void)setHistoryOBytes:(uint32_t)historyOBytes
{
    objc_setAssociatedObject(self, @selector(historyOBytes), [NSNumber numberWithInt:historyOBytes], OBJC_ASSOCIATION_ASSIGN);
}

- (uint32_t)historyOBytes
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}

- (void)setOldIBytes:(uint32_t)oldIBytes
{
    objc_setAssociatedObject(self, @selector(oldIBytes), [NSNumber numberWithInt:oldIBytes], OBJC_ASSOCIATION_ASSIGN);
}

- (uint32_t)oldIBytes
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}

- (void)setOldOBytes:(uint32_t)oldOBytes
{
    objc_setAssociatedObject(self, @selector(oldOBytes), [NSNumber numberWithInt:oldOBytes], OBJC_ASSOCIATION_ASSIGN);
}

- (uint32_t)oldOBytes
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}

- (void)setIsFirst:(BOOL)isFirst
{
    objc_setAssociatedObject(self, @selector(isFirst), @(isFirst), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)isFirst
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)getInterfaceBytes
{
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1)
    {
        return;
    }
    
    uint32_t iBytes = 0;
    uint32_t oBytes = 0;
    
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
    {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        
        if (ifa->ifa_data == 0)
            continue;
        
        /* Not a loopback device. */
        if (strncmp(ifa->ifa_name, "lo", 2))
        {
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
        }
    }
    if (!self.isFirst) {
        self.historyIBytes = iBytes;
        self.historyOBytes = oBytes;
        self.isFirst=YES;
    }

    self.nowIBytes = (iBytes - self.historyIBytes)/1024 - self.oldIBytes;
    self.nowOBytes = (oBytes - self.historyOBytes)/1024 - self.oldOBytes;
    
    
    if ((iBytes - self.historyIBytes)/1024 < self.oldIBytes) {
        self.nowIBytes = 0;
    }
    if ((oBytes - self.historyOBytes)/1024 < self.oldIBytes) {
        self.nowOBytes = 0;
    }
    
    self.oldIBytes = (iBytes - self.historyIBytes)/1024;
    self.oldOBytes = (oBytes - self.historyOBytes)/1024;
    
    freeifaddrs(ifa_list);
}


@end

@implementation NSObject (NetworkStateOrRSSI)

- (void)setNowIBytes:(uint32_t)nowIBytes
{
    objc_setAssociatedObject(self, @selector(nowIBytes), [NSNumber numberWithInt:nowIBytes], OBJC_ASSOCIATION_ASSIGN);
}

- (uint32_t)nowIBytes
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}

- (void)setNowOBytes:(uint32_t)nowOBytes
{
    objc_setAssociatedObject(self, @selector(nowOBytes), [NSNumber numberWithInt:nowOBytes], OBJC_ASSOCIATION_ASSIGN);
}

- (uint32_t)nowOBytes
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}



+ (GHNetworkType)networkType
{
    UIApplication *app = [UIApplication sharedApplication];
    
    NSArray *children = [[[app valueForKeyPath:@"statusBar"] valueForKeyPath:@"foregroundView"] subviews];
    
    int type = 0;
    for (id child in children) {
        if ([child isKindOfClass:NSClassFromString(@"UIStatusBarDataNetworkItemView")]) {
            type = [[child valueForKeyPath:@"dataNetworkType"] intValue];
        }
    }
    return type;
}

+ (int)wifiStrengthBars
{
    UIApplication *app = [UIApplication sharedApplication];
    
    NSArray *children = [[[app valueForKeyPath:@"statusBar"] valueForKeyPath:@"foregroundView"] subviews];
    
    int type = 0;
    for (id child in children) {
        if ([child isKindOfClass:NSClassFromString(@"UIStatusBarDataNetworkItemView")]) {
            type = [[child valueForKeyPath:@"wifiStrengthBars"] intValue];
        }
    }
    return type;
}

- (void)detectionBytes
{
    [self getInterfaceBytes];
}

@end
