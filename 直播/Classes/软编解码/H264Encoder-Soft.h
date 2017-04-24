//
//  H264Encoder-Soft.h
//  直播
//
//  Created by taoyi-two on 2017/3/31.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>

@interface H264Encoder_Soft : NSObject


- (void)prepareEncodeWithWidth:(int)width height:(int)height;

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;
- (void)endEncode;

@end
