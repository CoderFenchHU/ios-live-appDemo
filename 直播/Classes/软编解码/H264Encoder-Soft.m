//
//  H264Encoder-Soft.m
//  直播
//
//  Created by taoyi-two on 2017/3/31.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "H264Encoder-Soft.h"


@interface H264Encoder_Soft ()
{
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVOutputFormat *pOutputFmt;
    
    AVStream *pStream;
    AVFrame *pFrame;
    AVPacket packet;
    
    int frameIndex;
    uint8_t *buffer;
    
    int picture_size;
}
@end

@implementation H264Encoder_Soft
- (void)prepareEncodeWithWidth:(int)width height:(int)height{
    // 注册所有的存储格式和编码格式
    frameIndex = 0;
    
    av_register_all();
    
    // 创建AVFormatContext
    pFormatCtx = avformat_alloc_context();
    
    // 创建输出流
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"recoder.h264"];
    const char *outFile = [filePath UTF8String];
    
    pOutputFmt = av_guess_format(NULL, outFile, NULL);
    pFormatCtx->oformat = pOutputFmt;
    // 打开输出流
    if(avio_open(&pFormatCtx->pb, outFile, AVIO_FLAG_READ_WRITE) < 0){
        NSLog(@"文件打开失败");
        return;
    }
    
    // 创建AVStream pFormatCtx->streams[0]只有读取数据的时候才有流
    pStream = avformat_new_stream(pFormatCtx, 0);
    if (pStream == NULL) {
        NSLog(@"创建AVStream失败");
        avformat_free_context(pFormatCtx);
        return;
    }
    
    // 设置time_base 用于计算PTS/DTS  采样率  一般是1/90000
    pStream->time_base.num = 1;     // 分子
    pStream->time_base.den = 30; // 分母
    
    // 获取AVCodecContext  包含编码所有的参数
    pCodecCtx = pStream->codec;
    // 设置codec属性
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;  // 设置编码类型
    pCodecCtx->codec_id = AV_CODEC_ID_H264;      // 设置编码标准
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;     // 设置图片格式
    pCodecCtx->width = width;                    // 设置视频宽度
    pCodecCtx->height = height;                  // 设置视频高度
    pCodecCtx->max_b_frames = 3;                 // 设置连续最大B帧数
    pCodecCtx->time_base.num = 1;                // 设置帧率分子
    pCodecCtx->time_base.den = 25;               // 设置帧率分母
    pCodecCtx->gop_size = 12;                    // 设置GOP大小
    pCodecCtx->bit_rate = 400000;                // 设置比特率 单位时间内保存的数据量
    pCodecCtx->qmin = 10;                        // 设置最小音频质量
    pCodecCtx->qmax = 51;                        // 设置最大音频质量
    
    pCodecCtx->me_range = 16;
    pCodecCtx->max_qdiff = 4;
    pCodecCtx->qcompress = 0.6;
    // 如果是h264编码标准 必须设置options
    AVDictionary *options = 0;
    // 设置视频的编码速度点和视频质量的负载平衡
    if( av_dict_set(&options, "preset", "slow", 0) < 0){
        NSLog(@"set dict error");
        return;
    }
    // 设置视频延迟率
    if(av_dict_set(&options, "tune", "zerolatency", 0) < 0){
        NSLog(@"set dict error");
        return;
    }
    
   // av_dump_format(pFormatCtx, 0, outFile, 1);
    
    // 查找AVCodec
    AVCodec *pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"查找编码器失败");
        return;
    }
    int status = avcodec_open2(pCodecCtx, pCodec, &options);
    if(status < 0){
        NSLog(@"打开编码器失败");
        return;
    }
    
    pFrame = av_frame_alloc();
    // 创建AVFrame --> AVPaket
    pFrame = av_frame_alloc();
    
    if( avpicture_fill((AVPicture *)pFrame, buffer, AV_PIX_FMT_YUV420P, width, height) < 0){
        NSLog(@"fill error");
        return;
    }
    
    if(avformat_write_header(pFormatCtx, NULL) < 0) {
        NSLog(@"write header failue");
        return;
    }
    av_new_packet(&packet, pCodecCtx->width * pCodecCtx->height *3);
}

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer{
    // 从CMSampleBufferRef中获取CVPixelBufferRef
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 锁定内存地址
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        
        // 从CVPixelBufferRef获取YUV数据
        // 获取Y分量地址
        UInt8 *bufferPtrY = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        // 获取UV分量地址
        UInt8 *bufferPtrUV = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        // 根据像素获取图片的真是宽高
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        // 获取YUV分量长度
        size_t yBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        size_t uvBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height * 3 / 2);
        // 将NV12数据转成i420数据  iOS默认采集的NV12数据
        UInt8 *pU = yuv420_data + width * height;
        UInt8 *pV = pU + width * height / 4;
        for (int i = 0; i < height; i++) {
         memcpy(yuv420_data+i*width, bufferPtrY+i*yBPR, width);
        }
        for (int j = 0; j < height/2 ; j++) {
            for (int i = 0; i<width/2; i++) {
                *(pU++) = bufferPtrUV[i<<1];
                *(pV++) = bufferPtrUV[(i<<1) + 1];
            }
            bufferPtrUV += uvBPR;
        }
        // 设置AVFrame的属性
        // 设置YUV数据到AVFrame中
        pFrame->data[0] = yuv420_data;
        pFrame->data[1] = yuv420_data + width * height;
        pFrame->data[2] = yuv420_data + width * height * 5/4;
        pFrame->pts = frameIndex;
        // AVframe 设置宽高
        pFrame->width = (int)width;
        pFrame->height = (int)height;
        // 设置格式
        pFrame->format = AV_PIX_FMT_YUV420P;
        
        // 开始进行编码操作
        int got_picture = 0;
        if(avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture) < 0){
        //if(avcodec_receive_packet(pCodecCtx, &packet) < 0){
            NSLog(@"编码失败");
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);  // 解锁
            return;
        }
        // 将AVPacket写入文件
        if (got_picture == 1) {
            frameIndex++;
            NSLog(@"成功编码一帧数据");
            // 设置AVpacket的stream_index
            packet.stream_index = pStream->index;
            // 将packet写入文件
            if(av_write_frame(pFormatCtx, &packet) <0){
                NSLog(@"write frame failure");
                return;
            }
            // 释放资源
            av_free_packet(&packet);
        }
       
        free(yuv420_data);
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
}

- (void)endEncode{
    
    int ret = flush_encoder(pFormatCtx,0);
    if (ret < 0) {
        printf("Flushing encoder failed\n");
        return;
    }

    // 将FormatContext中没有写入的资源,全部写入
    av_write_trailer(pFormatCtx);
    // 释放资源
    avio_close(pFormatCtx->pb);
    avcodec_close(pCodecCtx);
    
    if (pStream) {
        av_free(pFrame);
        av_free(pFormatCtx);
    }
}


int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index){
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame){
            ret=0;
            break;
        }
        printf("Flush Encoder: Succeed to encode 1 frame!\tsize:%5d\n",enc_pkt.size);
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;  
}
@end
