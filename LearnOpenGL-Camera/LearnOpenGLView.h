//
//  LearnOpenGLView.h
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/21.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
/*
 GPUImageView中的FillModeType
 */
typedef NS_ENUM(NSUInteger, GPUImageFillModeType) {
    kGPUImageFillModeStretch,                       // Stretch to fill the full view, which may distort the image outside of its normal aspect ratio
    kGPUImageFillModePreserveAspectRatio,           // Maintains the aspect ratio of the source image, adding bars of the specified background color
    kGPUImageFillModePreserveAspectRatioAndFill     // Maintains the aspect ratio of the source image, zooming in on its center to fill the view
};

@interface LearnOpenGLView : UIView

@property (nonatomic , assign) BOOL isFullYUVRange;

@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;

@property (nonatomic, assign) GPUImageFillModeType fillModeType;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
