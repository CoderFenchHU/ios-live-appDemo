//
//  ViewController.m
//  直播
//
//  Created by taoyi-two on 2017/2/20.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import "ViewController.h"
#import "HFCaputureViewController.h"
#import "HFBeautyViewController.h"
#import "HFPlayerViewController.h"

@interface ViewController ()



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64;
    self.title = @"主页";
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    HFCaputureViewController *captureVc = [[HFCaputureViewController alloc] init];
    [self presentViewController:captureVc animated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"音视频采集";
            break;
        case 1:
            cell.textLabel.text = @"美颜相机";
            break;
        case 2:
            cell.textLabel.text = @"观看直播";
            break;
        case 3:
            cell.textLabel.text = @"采集播放";
            break;
        default:
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case 0:
        {
            HFCaputureViewController *captureVC = [[HFCaputureViewController alloc] init];
            [self.navigationController pushViewController:captureVC animated:YES];
        }   break;
        case 1:
        {
            HFBeautyViewController *beautyVc = [[HFBeautyViewController alloc] init];
            [self.navigationController pushViewController:beautyVc animated:YES];
        }
            break;
        case 3:
        {
            HFPlayerViewController *playVc = [[HFPlayerViewController alloc] init];
            [self.navigationController pushViewController:playVc animated:YES];
        }
            break;
        default:
            break;
    }
}

@end
