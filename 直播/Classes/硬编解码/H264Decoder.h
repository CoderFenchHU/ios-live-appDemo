//
//  H264Decoder.h
//  直播
//
//  Created by taoyi-two on 2017/3/31.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface H264Decoder : NSObject


- (void)decoder;

- (instancetype)initWithFilePath:(NSString *)filePath;
@end
