//
//  LearnOpenGLView.m
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/21.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import "LearnOpenGLView.h"
#import "FLOpenGLProgram.h"
#import "FLOpenGLContext.h"
#import <AVFoundation/AVUtilities.h>

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
		  0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
		  0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

@interface LearnOpenGLView ()
{
    GLuint frameBuffer,renderBuffer;
    
    GLint  positionAttribute,textureCoordAttribute;
    
    GLint  SamplerY,SamplerUV,colorConversionMatrixUniform;
    
    const GLfloat *_preferredConversion;
    
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    GLuint luminanceTexture, chrominanceTexture;
    
    GLint _backingWidth,_backingHeight;
    
    CGSize inputSize;
    
    GLfloat vertexPosition[8];
}

@property (nonatomic, strong) CAEAGLLayer  *mLayer;

@property (nonatomic, strong) FLOpenGLProgram *mProgram;



@end

@implementation LearnOpenGLView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}


- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _isFullYUVRange = YES;
        _fillModeType = kGPUImageFillModePreserveAspectRatioAndFill;
        _cameraPosition = AVCaptureDevicePositionFront;
        [self setupLayer];
        [self setupContext];
        [self setupProgram];
        [self setupFrameBuffer];
    }
    return self;
}

- (void)setupLayer
{
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    self.mLayer = (CAEAGLLayer *)self.layer;
    self.mLayer.drawableProperties = @{
                                       kEAGLDrawablePropertyRetainedBacking:@(NO),
                                       kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8,
                                       };
    self.mLayer.opaque = YES;
}

- (void)setupContext
{
    [[FLOpenGLContext shareGLContext] useAsCurrentContext];
}

- (void)setupProgram
{
    self.mProgram = [[FLOpenGLProgram alloc] initWithVertexShaderFilename:@"Shader" fragmentShaderFilename:@"Shader"];
    
    //bind Attribute
    [self.mProgram addAttribute:@"position"];
    [self.mProgram addAttribute:@"textureCoord"];

    if (![self.mProgram linkProgram]) {
        NSLog(@"linkProgram error...");
    }
    positionAttribute = [self.mProgram attributeIndex:@"position"];
    textureCoordAttribute = [self.mProgram attributeIndex:@"textureCoord"];
    
    SamplerY = [self.mProgram uniformIndex:@"SamplerY"];
    SamplerUV = [self.mProgram uniformIndex:@"SamplerUV"];
    colorConversionMatrixUniform = [self.mProgram uniformIndex:@"colorConversionMatrix"];
    
    [self.mProgram useProgram];
    
    glEnableVertexAttribArray(positionAttribute);
    glEnableVertexAttribArray(textureCoordAttribute);
}

- (void)setupFrameBuffer
{
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    
    [[[FLOpenGLContext shareGLContext] mContext] renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.mLayer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    if (_backingWidth == 0 || _backingHeight == 0) {
        [self destroyFramebuffer];
        NSLog(@"setupFrameBuffer error ...");
        return;
    }
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
    
    GLuint framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus == GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.bounds.size.width, self.bounds.size.height);
}

- (void)destroyFramebuffer
{
    //释放掉FBO需要切换到当前FBO所在的上下文吗????
    [[FLOpenGLContext shareGLContext] useAsCurrentContext];
    if (frameBuffer)
    {
        glDeleteFramebuffers(1, &frameBuffer);
        frameBuffer = 0;
    }
    
    if (renderBuffer)
    {
        glDeleteRenderbuffers(1, &renderBuffer);
        renderBuffer = 0;
    }
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (pixelBuffer != NULL) {
        CVReturn error;
        int width = (int)CVPixelBufferGetWidth(pixelBuffer);
        int height = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        if (!CGSizeEqualToSize(inputSize, CGSizeMake(width, height))) {
            inputSize = CGSizeMake(width, height);
            [self reloadVertexDataAttribut];
        }
        
        /*
         非常重要的一行代码,为啥呢???
         [[FLOpenGLContext shareGLContext] useAsCurrentContext];
         */
        
        //查询pixelBuffer的color space ,获取 YUV->RGB 使用的转换矩阵
         CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            // color range
            if (self.isFullYUVRange) {
                _preferredConversion = kColorConversion601FullRange;
            }
            else
            {
                _preferredConversion = kColorConversion601;
            }
        }
        else
        {
            _preferredConversion = kColorConversion709;
        }
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;
        
        //解析Y控件,创建纹理
        glActiveTexture(GL_TEXTURE2);
        /*
         GL_LUMINANCE:亮度
         */
        error = CVOpenGLESTextureCacheCreateTextureFromImage(
                                                             kCFAllocatorDefault,
                                                             [self textureCacheRef],
                                                             pixelBuffer, NULL,
                                                             GL_TEXTURE_2D,
                                                             GL_LUMINANCE,
                                                             width,
                                                             height,
                                                             GL_LUMINANCE,
                                                             GL_UNSIGNED_BYTE,
                                                             0,
                                                             &luminanceTextureRef
                                                             );
        
        if (error) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", error);
        }
        
        luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
        glBindTexture(GL_TEXTURE_2D, luminanceTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE3);
        
        /*
         这里为什么要除以2呢???
         我们相机采用的是YUV420的图像采集方式,YUV420的内存空间:
         Y分量:width * height
         U分量:width * height / 4;
         V分量:width * height / 4;
         这里取的是UV分量,就是1/2了;
         */
        error = CVOpenGLESTextureCacheCreateTextureFromImage(
                                                             kCFAllocatorDefault,
                                                             [self textureCacheRef],
                                                             pixelBuffer,
                                                             NULL,
                                                             GL_TEXTURE_2D,
                                                             GL_LUMINANCE_ALPHA,
                                                             width / 2,
                                                             height / 2,
                                                             GL_LUMINANCE_ALPHA,
                                                             GL_UNSIGNED_BYTE, 1,
                                                             &chrominanceTextureRef
                                                             );
        
        if (error) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", error);
        }
        
        chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
        glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
        
        // 绘制
        glViewport(0, 0, _backingWidth, _backingHeight);
        
        glClearColor(0.1f, 0.f, 0.f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        [self.mProgram useProgram];
        // 转换矩阵
        glUniformMatrix3fv(colorConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
        // 绑定纹理
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, luminanceTexture);
        glUniform1i(SamplerY, 2);
        
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
        glUniform1i(SamplerUV, 3);
        // 顶点坐标
        glVertexAttribPointer(positionAttribute, 2,GL_FLOAT , GL_FALSE , 0, vertexPosition);
        glEnableVertexAttribArray(positionAttribute);
        // 纹理坐标
        glVertexAttribPointer(textureCoordAttribute, 2, GL_FLOAT, GL_FALSE, 0, [self getTextureCoordAttribute]);
        glEnableVertexAttribArray(textureCoordAttribute);
        // 绘制三角形带
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
        [[FLOpenGLContext shareGLContext] presentBufferForDisplay];
        
        // 释放资源
        CFRelease(luminanceTextureRef);
        luminanceTextureRef = NULL;
        
        CFRelease(chrominanceTextureRef);
        chrominanceTextureRef = NULL;
    }
}

- (void)setFillModeType:(GPUImageFillModeType)fillModeType
{
    _fillModeType = fillModeType;
    [self reloadVertexDataAttribut];
}

- (void)reloadVertexDataAttribut
{
    if (!CGSizeEqualToSize(inputSize, CGSizeZero)) {
        CGSize currentViewSize = self.bounds.size;
        CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(inputSize, self.layer.bounds);
        CGFloat heightScaling, widthScaling;
        switch (_fillModeType) {
            case kGPUImageFillModeStretch:
            {
                widthScaling = 1.0;
                heightScaling = 1.0;
            }
                break;
            case kGPUImageFillModePreserveAspectRatio:
            {
                widthScaling = insetRect.size.width / currentViewSize.width;
                heightScaling = insetRect.size.height / currentViewSize.height;
            }
                break;
            case kGPUImageFillModePreserveAspectRatioAndFill:
            {
                widthScaling = currentViewSize.height / insetRect.size.height;
                heightScaling = currentViewSize.width / insetRect.size.width;
            }
                break;
            default:
                break;
        }
        
        vertexPosition[0] = - widthScaling;
        vertexPosition[1] = - heightScaling;
        vertexPosition[2] =   widthScaling;
        vertexPosition[3] = - heightScaling;
        vertexPosition[4] = - widthScaling;
        vertexPosition[5] =   heightScaling;
        vertexPosition[6] =   widthScaling;
        vertexPosition[7] =   heightScaling;
    }
}

// 纹理
- (const GLfloat *)getTextureCoordAttribute
{
    static const GLfloat textureDataFont[] =  { // 前置摄像头
        0.0, 0.0,
        1.0, 0.0,
        0.0, 1.0,
        1.0, 1.0
    };
    
    static const GLfloat textureDataBack[] =  { // 后置摄像头
        1.0, 0.0,
        0.0, 0.0,
        1.0, 1.0,
        0.0, 1.0
    };
    
    switch (_cameraPosition) {
        case AVCaptureDevicePositionBack:
            return textureDataBack;
            break;
        case AVCaptureDevicePositionFront:
            return textureDataFont;
            break;
        default:
            return textureDataFont;
            break;
    }
}


- (CVOpenGLESTextureCacheRef)textureCacheRef
{
    if (_videoTextureCache == nil) {
       CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [[FLOpenGLContext shareGLContext] mContext], NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"TextureCacheCreate error ...");
        }
    }
    return _videoTextureCache;
}

@end
