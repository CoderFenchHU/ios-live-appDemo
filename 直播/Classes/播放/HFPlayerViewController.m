//
//  HFPlayerViewController.m
//  直播
//
//  Created by taoyi-two on 2017/3/8.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "HFPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "H264Decoder-Soft.h"

@interface HFPlayerViewController ()
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *layer;
@end

@implementation HFPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    H264Decoder_Soft *decoder = [[H264Decoder_Soft alloc] init];
    [decoder decode];
    
    
    self.title = @"播放";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *playerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [playerBtn setTitle:@"播放" forState:UIControlStateNormal];
    playerBtn.frame = CGRectMake(100, 100, 40, 24);
    [playerBtn addTarget:self action:@selector(playMp4:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playerBtn];
}

- (IBAction)playMp4:(UIButton *)sender
{
    NSError *playError;
     NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"video.mp4"];
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithFormat:@"%@", filePath] error:nil];
    NSLog (@"file size: %llu, %@", [outputFileAttributes fileSize], [outputFileAttributes fileType]);
   
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filePath]];
    AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:item];
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    layer.frame = [UIScreen mainScreen].bounds;
    [layer setNeedsDisplay];
    [player play];
    self.player = player;
    self.layer = layer;
    self.view.backgroundColor = [UIColor blackColor];
    __weak typeof(self) weakSelf = self;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification *note) {
                            [weakSelf.player seekToTime:kCMTimeZero];
                            [weakSelf.player play];
                        }];

}


@end
