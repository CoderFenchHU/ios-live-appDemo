//
//  H264Decoder.m
//  直播
//
//  Created by taoyi-two on 2017/3/31.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "H264Decoder.h"
#import "AAPLEAGLLayer.h"
#import <VideoToolbox/VideoToolbox.h>

const char *pStartCode = "\x00\x00\x00\x01";

@interface H264Decoder ()
{
    // 读取的数据
    NSInteger _inputMaxSize;
    NSInteger _inputSize;
    uint8_t *_inputBuffer;
    // 解析数据
    NSInteger _frameSize;
    uint8_t *_frameBuffer;
    
    NSInteger _spsSize;
    uint8_t *_pSPS;
    
    NSInteger _ppsSize;
    uint8_t *_pPPS;
}

@property (nonatomic, weak) CADisplayLink *displayLink;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDescriptiion;

@end

@implementation H264Decoder


- (instancetype)initWithFilePath:(NSString *)filePath{
    if (self = [self init]) {
        CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
        self.displayLink = displayLink;
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        displayLink.frameInterval = 2;
        [self.displayLink setPaused:YES];
        
//        NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"video.h264"];
        self.inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
        
        self.queue = dispatch_get_global_queue(0, 0);
        
    }
    return self;
}

- (void)decoder{
   
//    AAPLEAGLLayer *layer = [[AAPLEAGLLayer alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
}

- (void)startDecoder{
    // 初始化
    _inputMaxSize = 720 * 1280;
    _inputSize = 0;
    _inputBuffer = malloc(_inputMaxSize);
    
    // 开始读取数据
    [self.displayLink setPaused:NO];
}

- (void)updateFrame{
    dispatch_async(self.queue, ^{
        // 读取数据
        [self readFrame];
        
        // 判断数据类型
        if (_frameSize == 0 && _frameBuffer == NULL) {
            [self.displayLink setPaused:YES];
            [self.inputStream close];
            return ;
        }
        // 解码 H264是大端数据 系统端数据->大端数据
        uint32_t naluSize = (uint32_t)(_frameSize - 4);
        uint32_t *pNALU = (uint32_t *)(_frameBuffer);
        *pNALU = CFSwapInt32HostToBig(naluSize);
        
        // 获取类型 0x27:sps 0x28:pps 0x25:IDR -> sps: 二进制 00 10 01 11
        // 取前五位: 0x07: sps 0x08:pps 0x05:IDR i帧
        int naluType = _frameBuffer[4] & 0x1F;
        switch (naluType) {
            case 0x07:  // sps
                _spsSize = _frameSize - 4;
                _pSPS = malloc(_spsSize);
                memcpy(_pSPS, _frameBuffer + 4, _spsSize);
                break;
            case 0x08:  // pps
                _ppsSize = _frameSize - 4;
                _pPPS = malloc(_spsSize);
                memcpy(_pPPS, _frameBuffer + 4, _ppsSize);
                break;
            case 0x05:  // IDR i帧
                // 硬解码
                // 创建VTDecompressionSessionRef 需要用到sps/pps
                [self initCompressionSession];
                
                //解码i帧
                [self decodeFrame];
                break;
                
            default:    // B\P帧数
                [self decodeFrame];
                break;
        }
    });
}

#pragma mark - 从文件中读取-个NALU的数据
- (void)readFrame{
    // 清空之前读取的数据
    if (_frameSize || _frameBuffer) {
        _frameSize = 0;
        free(_frameBuffer);
        _frameBuffer = nil;
    }
    
    // 读取数据
    if (_inputSize < _inputMaxSize && self.inputStream.hasBytesAvailable) {
        _inputSize += [self.inputStream read:_inputBuffer + _inputSize maxLength:_inputMaxSize - _inputSize];
    }
    
    // 获取解码想要的数据
    // 比较 前4位 是否为 00 00 00 01
    if (memcmp(_inputBuffer, pStartCode, 4) == 0) {
        uint8_t *pStart = _inputBuffer + 4;
        uint8_t *pEnd = _inputBuffer + _inputSize;
        
        while (pStart != pEnd) {
            if (memcmp(pStart - 3, pStartCode, 4) == 0) {
                // 获取下一个 00 00 00 01
                _frameSize = pStart - 3 - _inputBuffer;
                
                // 从inputBuffer中,拷贝到frameBuffer
                _frameBuffer = malloc(_frameSize);
                memcpy(_frameBuffer, _inputBuffer, _frameSize);
                
                // 将数据移动到最前方
                memmove(_inputBuffer, _inputBuffer + _frameSize, _inputSize - _frameSize);
                
                //  改变 inputsize 大小
                _inputSize -=  _frameSize;
            } else {
                pStart++;
            }
        }
    }
}

#pragma mark - 初始化VTDecompressionSessionRef
- (void)initCompressionSession{
    // 创建CMVideoFormatDescriptionRef
    const uint8_t *pParaSet[2] = {_pSPS, _pPPS};
    const size_t pParaSizes[2] = {_spsSize, _ppsSize};
    CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL,
                                                        2,
                                                        pParaSet,
                                                        pParaSizes,
                                                        4,
                                                        &_formatDescriptiion  // 创建VTDecompressionSessionRef参数
                                                        );
    
    // 创建VTDecompressionSessionRef  YUV(YCrCb) Y:亮度,UV:色度/饱和度 420P
    // 4:4:4 = 12 3通道
    // 4:1:1 = 6 YUV 420 2通道 节省一半空间
    NSDictionary *attrs = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decodeCallback;
    VTDecompressionSessionCreate(NULL,
                                 _formatDescriptiion,
                                 NULL,
                                 (__bridge CFDictionaryRef)attrs,
                                 &callbackRecord,
                                 &_decompressionSession
                                 );
    
}

#pragma mark - 解码数据
- (void)decodeFrame{
    // 获取CMBlockBufferRef
    CMBlockBufferRef blockBuffer;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                       (void *)_frameBuffer,  // 读取的数据
                                       _frameSize,            // 读取数据的size
                                       kCFAllocatorNull,
                                       NULL,
                                       0,
                                       _frameSize,
                                       0,
                                       &blockBuffer          // 输出blockBuffer
                                       );
    
    // CMSampleBufferRef
    size_t sizeArr[] = {_frameSize};
    CMSampleBufferRef sampleBuffer;
    CMSampleBufferCreateReady(NULL,
                              blockBuffer,
                              self.formatDescriptiion,
                              0,
                              0,
                              NULL,
                              0,
                              sizeArr,           //
                              &sampleBuffer      // 输出结果
                              );
    
    // 开始解码
    VTDecompressionSessionDecodeFrame(self.decompressionSession,
                                      sampleBuffer,
                                      0,
                                      (__bridge void * _Nullable)(self),
                                      NULL
                                      );
}

void decodeCallback(
                    void * CM_NULLABLE decompressionOutputRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTDecodeInfoFlags infoFlags,
                    CM_NULLABLE CVImageBufferRef imageBuffer,
                    CMTime presentationTimeStamp, 
                    CMTime presentationDuration ){
    // 创建layer
    
}

@end
