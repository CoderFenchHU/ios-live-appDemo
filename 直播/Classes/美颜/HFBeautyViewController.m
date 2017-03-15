//
//  HFBeautyViewController.m
//  直播
//
//  Created by taoyi-two on 2017/2/21.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "HFBeautyViewController.h"
#import <GPUImage.h>
#import "GPUImageBeautyFilter.h"
#import <YYKit.h>

#define SCREEN_SIZE  ([UIScreen mainScreen].bounds.size)
#define SCREEN_BOUNDS ([UIScreen mainScreen].bounds)

@interface HFBeautyViewController ()
@property (strong, nonatomic) GPUImageVideoCamera *videoCamera;
@property (strong, nonatomic) GPUImageBrightnessFilter *brightnessFilter;
@property (strong, nonatomic) GPUImageBilateralFilter *bilateralFilter;
@property (strong, nonatomic) GPUImageView *gImageView;
@property (strong, nonatomic) GPUImageFilterGroup *groupFilter;
@end

@implementation HFBeautyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"美颜";
    UISwitch *swi = [[UISwitch alloc] init];
    swi.on = YES;
    [swi addTarget:self action:@selector(switchChange:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:swi];
    self.navigationItem.rightBarButtonItem = item;
    
    [self setupCamare];
    // Do any additional setup after loading the view.
    
    [self setupSlider];
}

- (void)viewDidAppear:(BOOL)animated
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            CGRect frame = self.navigationController.navigationBar.frame;
            frame.origin.y = -64;
            self.navigationController.navigationBar.frame = frame;
        }];
    });
}

- (void)setupSlider
{
    // 磨皮滑动条
    UILabel *bilateralLabel = [[UILabel alloc] init];
    bilateralLabel.text = @"磨皮";
    bilateralLabel.left = 20;
    bilateralLabel.top = SCREEN_SIZE.height - 180;
    [bilateralLabel sizeToFit];
    [self.view addSubview:bilateralLabel];
    
    UISlider *bilateralSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, SCREEN_SIZE.height - 180, SCREEN_SIZE.width - 100, 20)];
    [bilateralSlider addTarget:self action:@selector(bilateralChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:bilateralSlider];
    
    // 美白滑动条
    UILabel *brightnessLabel = [[UILabel alloc] init];
    brightnessLabel.text = @"美白";
    brightnessLabel.left = 20;
    brightnessLabel.top = SCREEN_SIZE.height - 120;
    [brightnessLabel sizeToFit];
    [self.view addSubview:brightnessLabel];
    
    UISlider *brightnessSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, SCREEN_SIZE.height - 120, SCREEN_SIZE.width - 100, 20)];
    [brightnessSlider addTarget:self action:@selector(brightnessChanged:) forControlEvents:UIControlEventValueChanged];
    brightnessSlider.maximumValue = 1.0;
    [self.view addSubview:brightnessSlider];
    
    
/*

 
 */
}


-(void)setupCamare{
    GPUImageVideoCamera *videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera = videoCamera;
    
    // 创建美颜相机
    GPUImageView *gImageView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    [self.view insertSubview:gImageView atIndex:0];
    _gImageView = gImageView;
    
    // 设置美颜滤镜
    GPUImageFilterGroup *groupFilter = [[GPUImageFilterGroup alloc] init];
    // 磨皮滤镜
    GPUImageBilateralFilter *bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    _bilateralFilter = bilateralFilter;
    [groupFilter addTarget:bilateralFilter];
    // 美白滤镜
    GPUImageBrightnessFilter *briggtnessFilter = [[GPUImageBrightnessFilter alloc] init];
    _brightnessFilter = briggtnessFilter;
    [groupFilter addTarget:briggtnessFilter];
    // 设置滤镜组
    [bilateralFilter addTarget:briggtnessFilter];
    [groupFilter setInitialFilters:@[bilateralFilter]];
    groupFilter.terminalFilter = briggtnessFilter;
    
    // 添加响应链
    [videoCamera addTarget:groupFilter];
    [groupFilter addTarget:gImageView];
    _groupFilter = groupFilter;
    
    // 开始采集
    [videoCamera startCameraCapture];
    
}

#pragma mark - 交互
// 改变磨皮值
- (void)bilateralChanged:(UISlider *)sender
{
    CGFloat maxV = 10.0;
    [_bilateralFilter setDistanceNormalizationFactor:(maxV - sender.value)];
}

// 改变美白值
- (void)brightnessChanged:(UISlider *)sender
{
    _brightnessFilter.brightness = sender.value;
}

// 开\关 美颜效果
- (void)switchChange:(UISwitch *)sender
{
    if (sender.isOn) {  // 打开美颜
        [_videoCamera removeAllTargets];
        
        [_videoCamera addTarget:_groupFilter];
        [_groupFilter addTarget:_gImageView];
        
//        GPUImageBeautifyFilter *beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
//        [_videoCamera addTarget:beautifyFilter];
//        [beautifyFilter addTarget:_gImageView];
        
    } else {            // 关闭美颜
        [_videoCamera removeAllTargets];
        [_videoCamera addTarget:_gImageView];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [UIView animateWithDuration:0.25 animations:^{
        if (self.navigationController.navigationBar.top < 0) {
            
            self.navigationController.navigationBar.top = 20;
        } else self.navigationController.navigationBar.top = -64;
    }];
}

@end
