//
//  HFSocket.h
//  直播
//
//  Created by taoyi-two on 2017/4/14.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, HFSocketOffLineType) {
    HFSocketOffLineTypeBySever,
    HFSocketOffLineTypeClientCut,
};


#import "single.h"

@interface HFSocket : NSObject

/** host */
@property (copy, nonatomic) NSString *host;

/** port  */
@property (assign, nonatomic) NSInteger port;

- (BOOL)connect;

- (BOOL)connectToHost:(NSString *)address andPort:(NSInteger)port;


/** 断开形式 */
@property (assign, nonatomic) HFSocketOffLineType offLineType;

/** 心跳包 */
@property (assign, nonatomic) NSTimeInterval heartBeat;

// 断开链接
- (void)cutOffSocket;

@end
