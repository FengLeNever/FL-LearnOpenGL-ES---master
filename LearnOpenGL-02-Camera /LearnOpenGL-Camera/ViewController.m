//
//  ViewController.m
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/21.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import "ViewController.h"
#import "LearnOpenGLView.h"
#import <AVFoundation/AVFoundation.h>


@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) LearnOpenGLView *displayView;

@property (nonatomic, strong) AVCaptureSession *caputreSession;

@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;

@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;

@end

@implementation ViewController
{
    dispatch_queue_t mProcessQueue;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // 相机位置
    AVCaptureDevicePosition cameraPosition = AVCaptureDevicePositionBack;
    
    self.displayView = [[LearnOpenGLView alloc] initWithFrame:self.view.bounds];
    self.displayView.cameraPosition = cameraPosition;
    self.displayView.fillModeType = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:self.displayView];
    
    self.caputreSession = [[AVCaptureSession alloc] init];
    //初始化相机输入
    AVCaptureDevice *cameraDevice = nil;
    NSArray *deviceArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in deviceArray) {
        if ([device position] == cameraPosition) {
            cameraDevice = device;
        }
    }
    if (cameraDevice == nil) {
        NSLog(@"cameraDevice init error ...");
    }
    NSError *error = nil;
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:&error];
    if (error || self.videoInput == nil) {
        NSLog(@"self.videoInput init error ...");
    }
    if ([self.caputreSession canAddInput:self.videoInput]) {
        [self.caputreSession addInput:self.videoInput];
    }
    
    mProcessQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    //视频输出
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    /*
     1,修改视频数据格式
     kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
     kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
     都是YUV420格式,都是双planar,区别在于 FullRange : (luma=[0,255] chroma=[1,255]) VideoRange : (luma=[16,235] chroma=[16,240])
     相对应的在shader中使用的转换矩阵不同
     */
    [self.videoOutput setVideoSettings:@{
                                         (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                                         }];
    
    [self.videoOutput setSampleBufferDelegate:self queue:mProcessQueue];
    if ([self.caputreSession canAddOutput:self.videoOutput]) {
        [self.caputreSession addOutput:self.videoOutput];
    }
    /*
     2,修改分辨率
     */
    [self.caputreSession setSessionPreset:AVCaptureSessionPreset640x480];
    
    AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];

    [self.caputreSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.displayView displayPixelBuffer:pixelBuffer];
}








@end
