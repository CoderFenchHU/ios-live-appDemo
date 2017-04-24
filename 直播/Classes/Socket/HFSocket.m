//
//  HFSocket.m
//  直播
//
//  Created by taoyi-two on 2017/4/14.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "HFSocket.h"
#import <GCDAsyncSocket.h>

@interface HFSocket () <GCDAsyncSocketDelegate>

@property(strong, nonatomic)GCDAsyncSocket *socket;

/** timer */
@property (strong, nonatomic) NSTimer *timer;

@end

@implementation HFSocket
// 单例实现
// ARC下实现
+ (instancetype)shareSocket
{
    return [[self alloc] init];
}

static HFSocket *_instance;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
- (id)copyWithZone:(NSZone *)zone
{
    return _instance;
}
- (id)mutableCopyWithZone:(NSZone *)zone
{
    return _instance;
}
- (instancetype)init{
    if (self = [super init]) {
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    return self;
}


- (BOOL)connect{
    return [self connectToHost:self.host andPort:self.port];
}

- (BOOL)connectToHost:(NSString *)host andPort:(NSInteger)port{
    self.heartBeat = 10;
    NSError *error;
    BOOL ref;
    self.host = host;
    self.port = port;
    ref = [self.socket connectToHost:host onPort:port error:&error];
    if (error || !ref) {
        return NO;
    }
    return ref;
}

- (void)cutOffSocket{
    self.offLineType = HFSocketOffLineTypeClientCut;
    [self.socket writeData:[@"quit" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3 tag:1];
    [self.timer invalidate];
    self.timer = nil;
    [self.socket disconnect];
}


#pragma mark - socket delegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    NSLog(@"连接%@成功", host);
    [sock readDataWithTimeout:-1 tag:0];
    NSString *heartBeat = @"clientHeartBeat";
    NSData *heartBeatData = [heartBeat dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:heartBeatData withTimeout:30 tag:0];
    NSLog(@"发送连接成功心跳包");
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.heartBeat target:self selector:@selector(longConnectToSocket) userInfo:nil repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"socket Disconnect with type:%ld", self.offLineType);
    switch (self.offLineType) {
        case HFSocketOffLineTypeClientCut:
            break;
        case HFSocketOffLineTypeBySever:
            [self connect];
            break;
        default:
            break;
    }
}
- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag{
    NSLog(@"接受到一个Partial数据");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSLog(@"接受到一个数据%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    [sock readDataWithTimeout:-1 tag:0];
}
// 发送心跳包
- (void)longConnectToSocket{
    NSString *heartBeat = @"clientHeartBeat";
    NSData *heartBeatData = [heartBeat dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:heartBeatData withTimeout:30 tag:0];
    NSLog(@"发送心跳包");
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    
    
}
@end
