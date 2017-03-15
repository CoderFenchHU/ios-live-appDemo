//
//  HFCaputureViewController.m
//  直播
//
//  Created by taoyi-two on 2017/2/20.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "HFCaputureViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AFNetworking.h>
//#import <IJKMediaFramework/IJKMediaFramework.h>
#import <GPUImage.h>

@interface HFCaputureViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    dispatch_queue_t _queue;
    NSString *_filePath;
    
    BOOL _isRecording;
    BOOL _readyForVideo;
    BOOL _readyForAudio;
    BOOL _VideoWritten;
    
    CMTime _timeOffset;
    CMTime _videoTimeStamp;
    CMTime _audioTimeStamp;
}

@property (strong, nonatomic) AVCaptureDeviceInput *curVideoDeviceInput;
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureConnection *audioConnection;
@property (weak, nonatomic) AVCaptureVideoPreviewLayer *preLayer;
@property (weak, nonatomic) UIImageView *focImageView;
@property (strong, nonatomic) AVAssetWriter *assetWrite;
@property (strong, nonatomic) AVAssetWriterInput *audioAssetInput;
@property (strong, nonatomic) AVAssetWriterInput *videoAssetInput;

@end

@implementation HFCaputureViewController

- (UIImageView *)focImageView
{
    if (!_focImageView) {
        UIImageView *focImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"focus"]];
        [self.view addSubview:focImageView];
        _focImageView = focImageView;
    }
    return _focImageView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"音视频采集";
    _queue = dispatch_queue_create("FENCH_QUEUE", DISPATCH_QUEUE_SERIAL);
    
    [self setupCapture];
    [self initAssetWrite];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"切换镜头" style:UIBarButtonItemStylePlain target:self action:@selector(changeCapture)];
    [self.navigationItem setRightBarButtonItem:item];
    
    _videoTimeStamp = kCMTimeZero;
    _audioTimeStamp = kCMTimeZero;
    _timeOffset = kCMTimeZero;
    _isRecording = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// 初始化音视频采集
- (void)setupCapture
{
    // 创建捕捉会话
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    _session = session;
    _session.sessionPreset = AVCaptureSessionPresetMedium;
    
    
    // 获取摄像头
    AVCaptureDevice *VideoDev = [self getDeviceWithPosision:AVCaptureDevicePositionFront];
    
   
    if (VideoDev == nil) {
        NSLog(@"can not catch front camare!");
    }
    // 创建视频输入对象
    NSError *videoErr = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:VideoDev error:&videoErr];
    if (videoErr) {
        NSLog(@"creat video device input error!");
        return;
    }
    _curVideoDeviceInput = videoInput;
    
    // 获取声音设备
    AVCaptureDevice *audioDev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    NSError *audioErr = nil;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDev error:&audioErr];
    if (audioErr) {
        NSLog(@"creat audio device input error!");
        return;
    }
    
    // 添加输入流到会话
    if ([session canAddInput:videoInput]) {
        [session addInput:videoInput];
    } else NSLog(@"add video input error!");
    if ([session canAddInput:audioInput]) {
        [session addInput:audioInput];
    } else NSLog(@"add audio input error");
    // 获取视频数据输出设备
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    dispatch_queue_t videoQue = dispatch_queue_create("cf.fench.video", DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:self queue:videoQue];
    
    // 添加输出流到会话
    if ([session canAddOutput:videoOutput]) {
        [session addOutput:videoOutput];
    }
    
    // 获取音频数据输出设备
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t  audioQue = dispatch_queue_create("cf.fench.audio", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:self queue:audioQue];
    
    // 添加输出流到会话
    if ([session canAddOutput:audioOutput]) {
        [session addOutput:audioOutput];
    }
//    AVCaptureMovieFileOutput *moveOutput = [[AVCaptureMovieFileOutput alloc] init];
   
    
    // 视频输入输出连接
    AVCaptureConnection *videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    _videoConnection= videoConnection;
    AVCaptureConnection *audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
    _audioConnection = audioConnection;
    
    // 添加视频预览图层
    AVCaptureVideoPreviewLayer *preLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    preLayer.frame = [UIScreen mainScreen].bounds;
    [self.view.layer insertSublayer:preLayer atIndex:0];
    _preLayer = preLayer;
    
    NSString *sessionPreset = [_session sessionPreset];
    if ([_session canSetSessionPreset:sessionPreset]) {
        [_session setSessionPreset:sessionPreset];
    }
    
    if ([_videoConnection isVideoStabilizationSupported]) {
        _videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard;
        [_session commitConfiguration];
//        [_session startRunning];po
    }
    
    
    // 开启session
    [session startRunning];
}


//  根据posision 获取摄像头
- (AVCaptureDevice *)getDeviceWithPosision:(AVCaptureDevicePosition)posision
{
    NSArray *decs = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *dec in decs) {
        if (dec.position == posision) {     // 获取前置摄像头  系统默认是后置摄像头
            return dec;
        }
    }
    return nil;
}

#pragma mark - 初始化Asset Write
- (void)initAssetWrite
{
    NSString *fileName = [@"video" stringByAppendingPathExtension:@"mp4"];
    NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:fileName];
    
    _filePath = videoPath;
    unlink([videoPath UTF8String]);
    NSLog(@"------------- %@", videoPath);
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    
//    NSString *audioPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"audio.mp4"];
//    NSURL *audioURL = [NSURL fileURLWithPath:audioPath];
    
    AVAssetWriter *assetWrite = [AVAssetWriter assetWriterWithURL:videoURL fileType:AVFileTypeQuickTimeMovie error:nil];
    self.assetWrite = assetWrite;
    
    // 配置视频参数
    NSDictionary *videoCleanApertureSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                @480, AVVideoCleanApertureWidthKey,
                                                @480, AVVideoCleanApertureHeightKey,
                                                @2, AVVideoCleanApertureHorizontalOffsetKey,
                                                @2, AVVideoCleanApertureVerticalOffsetKey,
                                                nil];
    
    NSDictionary *videoAspecRatioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                            @1, AVVideoPixelAspectRatioHorizontalSpacingKey,
                                            @1, AVVideoPixelAspectRatioVerticalSpacingKey,
                                            nil];
    
    NSDictionary *codecSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @(1024*1000), AVVideoAverageBitRateKey,
                                  @30, AVVideoMaxKeyFrameIntervalKey,
                                  videoCleanApertureSettings, AVVideoCleanApertureKey,
                                  videoAspecRatioSetting, AVVideoPixelAspectRatioKey,
                                  nil];
    
    NSDictionary *videoSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                  AVVideoCodecH264, AVVideoCodecKey,
                                  codecSetting, AVVideoCompressionPropertiesKey,
                                  @480, AVVideoWidthKey,
                                  @480, AVVideoHeightKey,
                                  nil];
    
    AVAssetWriterInput *videoAssetInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSetting];
    NSParameterAssert(videoAssetInput);
    
    videoAssetInput.expectsMediaDataInRealTime = YES;
    self.videoAssetInput = videoAssetInput;
    // 配置音频参数
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    NSDictionary *audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @(kAudioFormatMPEG4AAC), AVFormatIDKey,
                                        @2, AVNumberOfChannelsKey,
                                        @44100.0, AVSampleRateKey,
                                        @64000, AVEncoderBitRateKey,
                                        [NSData dataWithBytes:&acl length:sizeof(acl)], AVChannelLayoutKey,
                                        nil];
    
    AVAssetWriterInput *audioAssetInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSetting];
    audioAssetInput.expectsMediaDataInRealTime = YES;
    self.audioAssetInput = audioAssetInput;
}

#pragma mark - 设置Asset Write Video Input
- (BOOL)setupAssetWriteVideoInput:(CMFormatDescriptionRef)currentFormatDescription
{
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
    
    float bitRate = 87500.0f * 8.0f;
    NSInteger frameInterval = 30;
    
    NSDictionary *compressionSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @(bitRate), AVVideoAverageBitRateKey,
                                        @(frameInterval), AVVideoMaxKeyFrameIntervalKey
                                        , nil];
    
    NSDictionary *videoCopressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                             AVVideoCodecH264, AVVideoCodecKey,
                                             AVVideoScalingModeResizeAspectFill, AVVideoScalingModeKey,
                                             @(dimensions.width), AVVideoWidthKey,
                                             @(dimensions.height), AVVideoHeightKey,
                                             compressionSetting, AVVideoCompressionPropertiesKey,
                                             nil];
    
    if ([self.assetWrite canApplyOutputSettings:videoCopressionSettings forMediaType:AVMediaTypeVideo]) {
        _videoAssetInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCopressionSettings];
        _videoAssetInput.expectsMediaDataInRealTime = YES;
        _videoAssetInput.transform = CGAffineTransformIdentity;
        NSLog(@"prepared video-in with compression settings bps %f frameInterval %ld", bitRate, frameInterval);
        if ([self.assetWrite canAddInput:_videoAssetInput]) {
            [self.assetWrite addInput:_videoAssetInput];
            return YES;
        } else {
            NSLog(@"asserWrite cann't add input!");
            return NO;
        }
    } else {
        NSLog(@"Asset writer cann't apply video output settings!");
        return NO;
    }
}

#pragma mark - 设置Asset Write Audio Input
- (BOOL)setupAssetWriteAudioInput:(CMFormatDescriptionRef)currentFormatDescription
{
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    if (!asbd) {
        NSLog(@"Audio stream description used with non-audio format description");
        return NO;
    }
    
    unsigned int channels = asbd->mChannelsPerFrame;
    double sampleRate = asbd->mSampleRate;
    int bitRate = 64000;
    NSLog(@"Audio Stream setup, channels (%d) sampleRate (%f)", channels, sampleRate);
    size_t aclSize = 0;
    const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
    NSData *currentChannelLayoutData = (currentChannelLayout && aclSize > 0) ? [NSData dataWithBytes:currentChannelLayout length:aclSize] : [NSData data];
    
    // 设置音频参数
    NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              @(kAudioFormatMPEG4AAC), AVFormatIDKey,
                                              @(channels), AVNumberOfChannelsKey,
                                              @(sampleRate), AVSampleRateKey,
                                              @(bitRate), AVEncoderBitRateKey,
                                              currentChannelLayoutData, AVChannelLayoutKey,
                                              nil];
    // 设置AssetWriteInput
    if ([self.assetWrite canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
        self.audioAssetInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
        self.audioAssetInput.expectsMediaDataInRealTime = YES;
        NSLog(@"prepared audio-in with compression settings sampleRate (%f) channels (%d) bitRate (%d)", sampleRate, channels, bitRate);
        
        if ([self.assetWrite canAddInput:self.audioAssetInput]) {
            [self.assetWrite addInput:self.audioAssetInput];
        } else {
            NSLog(@"AssetWrite cann't add asset audio input!");
            return NO;
        }
    } else {
        NSLog(@"AssetWrite cann't apply audio output settings!");
        return NO;
    }
    
    return YES;
}

// 切换摄像头
- (IBAction)changeCapture{
    
    AVCaptureDevicePosition curPosision = _curVideoDeviceInput.device.position;
    AVCaptureDevicePosition tarPosision = curPosision == AVCaptureDevicePositionFront ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    AVCaptureDevice *tarDevice = [self getDeviceWithPosision:tarPosision];
    NSError *error = nil;
    AVCaptureDeviceInput *tarDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:tarDevice error:&error];
    if (error || !tarDeviceInput) {
        NSLog(@"change target device input error");
    }
    [_session removeInput:_curVideoDeviceInput];
    [_session addInput:tarDeviceInput];
    _curVideoDeviceInput = tarDeviceInput;
    
}

// 点击屏幕 聚焦
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
//    CGPoint point = [[touches anyObject] locationInView:self.view];
//    // 转换为摄像头的点
//    CGPoint camareP = [_preLayer captureDevicePointOfInterestForPoint:point];
//    
//    // 显示聚焦图片 做动画
//    self.focImageView.center = point;
//    self.focImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
//    self.focImageView.alpha = 1.0;
//    [UIView animateWithDuration:1.0 animations:^{
//        self.focImageView.transform = CGAffineTransformIdentity;
//    }completion:^(BOOL finished) {
//        self.focImageView.alpha = 0;
//    }];
//    
//    // 设置聚焦/曝光
//    AVCaptureDevice *device = _curVideoDeviceInput.device;
//    [device lockForConfiguration:nil];
//    if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
//        [device setFocusMode:AVCaptureFocusModeAutoFocus];
//    } else NSLog(@"camare focus failure!");
//    if ([device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
//        [device setExposureMode:AVCaptureExposureModeAutoExpose];
//    } else NSLog(@"camare exposure failure!");
//    if ([device isExposurePointOfInterestSupported]) {
//        [device setExposurePointOfInterest:camareP];
//    }
//    [device unlockForConfiguration];
//    [self changeCapture];
    
    _isRecording = NO;
    _isRecording = NO;
    _readyForAudio = NO;
    _readyForVideo = NO;
    [_videoAssetInput markAsFinished];
    [_audioAssetInput markAsFinished];
    [_assetWrite finishWritingWithCompletionHandler:^{
        NSLog(@"asset writer finish write status %ld", _assetWrite.status);
    }];
    
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithFormat:@"%@", _filePath] error:nil];
    NSLog (@"file size: %llu", [outputFileAttributes fileSize]);
}

#pragma mark - delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    CFRetain(formatDescription);
    CFRetain(sampleBuffer);
    
    dispatch_async(_queue, ^{
        if (!CMSampleBufferDataIsReady(sampleBuffer)) {
            NSLog(@"Sample buffer data is not ready!");
            CFRelease(sampleBuffer);
            CFRelease(formatDescription);
            return;
        }
//        if (!_isRecording) {
//            CFRelease(sampleBuffer);
//            CFRelease(formatDescription);
//            return;
//        }
        if (!self.assetWrite) {
            CFRelease(sampleBuffer);
            CFRelease(formatDescription);
            return;
        }
        
        BOOL isAudio = connection == _videoConnection ? NO : YES;
        BOOL isVideo = connection == _audioConnection ? NO : YES;
        
        BOOL wasReadyToRecord = _readyForAudio && _readyForVideo;
        if (isAudio && !_readyForAudio) {
            _readyForAudio = [self setupAssetWriteAudioInput:formatDescription];
            NSLog(@"Ready for audio %d", _readyForAudio);
        }
        if (isVideo && !_readyForVideo) {
            _readyForVideo = (unsigned int)[self setupAssetWriteVideoInput:formatDescription];
        }
        
        BOOL isReadyToRecord = _readyForAudio && _readyForVideo;
        
        if (isAudio) {
            CMTime time = isVideo ? _videoTimeStamp : _audioTimeStamp;
            if (CMTIME_IS_VALID(time)) {
                CMTime pTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                if (CMTIME_IS_VALID(_timeOffset)) {
                    pTimeStamp = CMTimeSubtract(pTimeStamp, _timeOffset);
                }
                CMTime offset = CMTimeSubtract(pTimeStamp, _audioTimeStamp);
                _timeOffset = _timeOffset.value == 0 ? offset : CMTimeAdd(_timeOffset, offset);
                NSLog(@"new calculate offset %f valid %d", CMTimeGetSeconds(_timeOffset), CMTIME_IS_VALID(_timeOffset));
            } else {
                NSLog(@"Invalid audio timestamp, no offset update!");
            }
            _audioTimeStamp.flags = 0;
            _videoTimeStamp.flags = 0;
           
        }
        
        if (isVideo && isReadyToRecord) {
            CMSampleBufferRef bufferToWrite = NULL;
            if (_timeOffset.value > 0) {
                bufferToWrite = [self createOffsetSampleBuffer:sampleBuffer withTimeOfsset:_timeOffset];
                if (!bufferToWrite) {
                    NSLog(@"error subtracting the timeoffset frome samplebuffer!");
                }
            } else {
                bufferToWrite = sampleBuffer;
                CFRetain(bufferToWrite);
            }
            if (bufferToWrite) {
                CMTime time = CMSampleBufferGetPresentationTimeStamp(bufferToWrite);
                CMTime duration = CMSampleBufferGetDuration(bufferToWrite);
                if (duration.value > 0) {
                    time = CMTimeAdd(time, duration);
                }
                if (time.value > _videoTimeStamp.value) {
                    _videoTimeStamp = time;
                    _VideoWritten = YES;
                }
                CFRelease(bufferToWrite);
            }
        } else if(isAudio && isReadyToRecord){
            CMSampleBufferRef  buffertoWrite = NULL;
            if (_timeOffset.value > 0) {
                buffertoWrite = [self createOffsetSampleBuffer:sampleBuffer withTimeOfsset:_timeOffset];
                if (!buffertoWrite) {
                    NSLog(@"Error subtracting the timeoffset from the samplebuffer!");
                }
            } else {
                buffertoWrite = sampleBuffer;
                CFRetain(buffertoWrite);
            }
            if (buffertoWrite &&  _VideoWritten) {
                CMTime time = CMSampleBufferGetPresentationTimeStamp(buffertoWrite);
                CMTime duration = CMSampleBufferGetDuration(buffertoWrite);
                if (duration.value > 0) {
                    time = CMTimeAdd(time, duration);
                }
                if (time.value > _audioTimeStamp.value) {
                    [self writeSampleBuffer:buffertoWrite ofType:AVMediaTypeAudio];
                    _audioTimeStamp = time;
                }
                CFRelease(buffertoWrite);
            }
        }
        if (!wasReadyToRecord && isReadyToRecord) {
            
        }
        CFRelease(sampleBuffer);
        CFRelease(formatDescription);
    });
    
}

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    NSLog(@"asset writer status = %ld", self.assetWrite.status);
    if (_assetWrite.status == AVAssetWriterStatusUnknown) {
        if ([_assetWrite startWriting]) {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.assetWrite startSessionAtSourceTime:startTime];
            NSLog(@"asset write start writing with status %ld", self.assetWrite.status);
        } else NSLog(@"asset write writing error %ld", self.assetWrite.status);
    }
    
    if (self.assetWrite.status == AVAssetWriterStatusFailed) {
        NSLog(@"asset write error %ld", self.assetWrite.status);
        return;
    }
    
    if (self.assetWrite.status == AVAssetWriterStatusWriting) {
        if (mediaType == AVMediaTypeVideo) {
            if (self.videoAssetInput.readyForMoreMediaData) {
                if (![self.videoAssetInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"Asset writer error appending video %@", [self.assetWrite error]);
                }
            }
        }
        if (mediaType == AVMediaTypeAudio) {
            if (self.audioAssetInput.readyForMoreMediaData) {
                if (![self.audioAssetInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"asset writer error appending audio %@", [self.assetWrite error]);
                }
            }
        }
    }
}

- (CMSampleBufferRef)createOffsetSampleBuffer:(CMSampleBufferRef)sampleBuffer withTimeOfsset:(CMTime)timeOffset
{
    CMItemCount itemCount;
    OSStatus status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, NULL, &itemCount);
    if (status) {
        NSLog(@"cann't detemine the timing info count!");
        return NULL;
    }
    
    CMSampleTimingInfo *timingInfo = (CMSampleTimingInfo *)malloc(sizeof(CMSampleTimingInfo)* (unsigned long)itemCount);
    if (!timingInfo) {
        NSLog(@"cann't allocte timing info!");
        return NULL;
    }
    
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, timingInfo, &itemCount);
    if (status) {
        free(timingInfo);
        timingInfo = NULL;
        return NULL;
    }
    
    for (CMItemCount i = 0; i < itemCount; i++) {
        timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
        timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
    }
    
    CMSampleBufferRef outputSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, timingInfo, &outputSampleBuffer);
    
    if (timingInfo) {
        free(timingInfo);
        timingInfo = NULL;
    }
    return outputSampleBuffer;
}

- (CMSampleBufferRef)offsetTimmintWithSampleBufferForVideo:(CMSampleBufferRef)sampleBuffer
{
    CMSampleBufferRef newSampleBuffer;
    CMSampleTimingInfo sampleTimingInfo;
    sampleTimingInfo.duration = CMTimeMake(1, 30);
    sampleTimingInfo.presentationTimeStamp = CMTimeMake(0, 30);
    sampleTimingInfo.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
                                          sampleBuffer,
                                          1,
                                          &sampleTimingInfo,
                                          &newSampleBuffer);
    
    
    return newSampleBuffer;
}


@end
