//
//  GPUImageBeautyFilter.h
//  直播
//
//  Created by taoyi-two on 2017/2/22.
//  Copyright © 2017年 taoyitech. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@class GPUImageCombinationFilter;

@interface GPUImageBeautifyFilter : GPUImageFilterGroup {
    GPUImageBilateralFilter *bilateralFilter;
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
    GPUImageCombinationFilter *combinationFilter;
    GPUImageHSBFilter *hsbFilter;
}

@end
