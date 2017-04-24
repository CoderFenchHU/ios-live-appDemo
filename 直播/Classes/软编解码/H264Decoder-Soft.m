//
//  H264Decoder-Soft.m
//  直播
//
//  Created by taoyi-two on 2017/4/12.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "H264Decoder-Soft.h"
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>

@interface H264Decoder_Soft ()
{
    AVFormatContext *_pFormatCtx;
    AVCodecContext *_pCodecCtx;
    AVFrame *_pFrame;
    AVPacket _packet;
    int _videoIndex;
}

@end

@implementation H264Decoder_Soft

- (void)prepareDecoder{
    
    // 初始化
    av_register_all();
    
    // 打开输入文件
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"recoder.h264" ofType:nil];
    const char *inputFile = [filePath UTF8String];
    if(avformat_open_input(&_pFormatCtx, inputFile,NULL, NULL) < 0) {
        NSLog(@"open input file failue");
        avformat_free_context(_pFormatCtx);
        return;
    }
    
    // 差早AVStream信息
    if(avformat_find_stream_info(_pFormatCtx, NULL) < 0){
        NSLog(@"find stream failure");
        avformat_free_context(_pFormatCtx);
        return;
    }
    
    // 获取视频信息
    _videoIndex = -1;
    for (int i = 0; _pFormatCtx->nb_streams; i++) {
        if (_pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoIndex = i;
            break;
        }
    }
    
    // 获取AVStream
    AVStream *pStream = _pFormatCtx->streams[_videoIndex];
    _pCodecCtx = pStream->codec;
    
    // 查找编码器
    AVCodec  *pCodec = avcodec_find_decoder(_pCodecCtx->codec_id);
    if (pCodec == NULL) {
        avformat_free_context(_pFormatCtx);
        NSLog(@"查找解码器失败");
        return;
    }
    
    // 打开解码器
    if(avcodec_open2(_pCodecCtx, pCodec, NULL) < 0){
        NSLog(@"打开解码器失败");
        return;
    }
    
    // 创建AVFrame
    _pFrame = av_frame_alloc();
}

- (void)decode{
    [self prepareDecoder];
    while (av_read_frame(_pFormatCtx, &_packet) >= 0) {
        int got_picture = -1;
        if (_packet.stream_index == _videoIndex) {
            if(avcodec_decode_video2(_pCodecCtx, _pFrame, &got_picture, &_packet) < 0){
                NSLog(@"解码失败");
                continue;
            }
        }
        
        if (got_picture) {
            NSLog(@"成功解码一帧数据");
            char *buf = (char *)malloc(_pFrame->width * _pFrame->height * 3/2);
            AVPicture *pic;
            pic = (AVPicture *)_pFrame;
            int  w = _pFrame->width;
            int  h = _pFrame->height;
            char *y = buf;
            char *u = y + w*h;
            char *v = u + w*h/4;
            for (int i = 0; i<h; i++) {
                memcpy(y+w*i, _pFrame->data[0]+_pFrame->linesize[0]*i, w);
            }
            
            for (int i=0; i<h/2; i++) {
                memcpy(u+w/2*i, _pFrame->data[1]+_pFrame->linesize[1]*i, w/2);
            }
            
            for (int i=0; i<h/2; i++) {
                memcpy(v+w/2*i, _pFrame->data[2]+_pFrame->linesize[2]*i, w/2);
            }
            
            
        }
    }
    
}
@end
