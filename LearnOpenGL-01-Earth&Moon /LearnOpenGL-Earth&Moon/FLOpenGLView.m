//
//  FLOpenGLView.m
//  LearnOpenGL-05
//
//  Created by FengLe on 2017/8/14.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import "FLOpenGLView.h"
#import <OpenGLES/ES2/gl.h>
#import "GLESMath.h"
#include "sphere.h"

@interface FLOpenGLView ()
{
    GLuint _frameBufferHandle;
    GLuint _colorRenderBuffer;
    GLuint _depthRenderBuffer;

    GLint _width;
    GLint _height;
    // uniform
    GLuint _samplerTexture;
    GLuint _modleViewMatrix;
    GLuint _projectionMatrix;
    //属性
    GLuint _ballVBO;
    GLuint _ballTextcoord;
    //纹理
    GLuint _earthTexture;
    GLuint _moonTexture;
}


@property (nonatomic, strong) CAEAGLLayer  *mLayer;

@property (nonatomic, strong) EAGLContext *mContext;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property GLuint program;

@property (nonatomic) GLfloat earthRotationAngleDegrees;

@property (nonatomic) GLfloat moonRotationAngleDegrees;

@end

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

static const GLfloat  SceneMoonRadiusFractionOfEarth = 0.45;
static const GLfloat  SceneMoonDistanceFromEarth = 2.0;
static const GLfloat  SceneEarthAxialTiltDeg = 23.5f;
static const GLfloat  SceneDaysPerMoonOrbit = 28.0f;

@implementation FLOpenGLView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (void)dealloc
{
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    
    glDeleteTextures(1, &_earthTexture);
    glDeleteTextures(1, &_moonTexture);
    glDeleteBuffers(1, &_ballVBO);
    glDeleteBuffers(1, &_ballTextcoord);
    glDeleteProgram(self.program);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupLayer];
        [self setupContext];
        [self setupOpenGL];
        [self setupDisplayLink];
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
    self.mContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (self.mContext == nil) {
        NSLog(@"!!!!!!!! alloc Context error");
    }
    if (![EAGLContext setCurrentContext:self.mContext]) {
        NSLog(@"!!!!!!!! set CurrentContext error");
    }
}

- (void)setupDisplayLink
{
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)setupOpenGL
{
    //设置FBO
    [self setupFrameBuffer];
    //编译Shader并Link program
    [self setupShader];
    //读取 Uniform
    _samplerTexture = glGetUniformLocation(self.program, "samplerTexture");
    _modleViewMatrix = glGetUniformLocation(self.program, "modelViewMatrix");
    _projectionMatrix = glGetUniformLocation(self.program, "projectionMatrix");
    
    //加载两个纹理
    _earthTexture = [self loadTextureWithImageName:@"Earth512x256.jpg"];
    _moonTexture = [self loadTextureWithImageName:@"Moon.jpg"];
    
    // 创建VBO,顶点buffer
    glGenBuffers(1, &_ballVBO);
    glBindBuffer(GL_ARRAY_BUFFER, _ballVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(sphereVerts), sphereVerts, GL_STATIC_DRAW);
    
    // 纹理 buffer
    glGenBuffers(1, &_ballTextcoord);
    glBindBuffer(GL_ARRAY_BUFFER, _ballTextcoord);
    glBufferData(GL_ARRAY_BUFFER, sizeof(sphereTexCoords), sphereTexCoords, GL_STATIC_DRAW);
}

- (void)setupFrameBuffer
{
    //设置FBO,并给FBO绑定了colorRenderBuffer , depthRenderBuffer,如果不添加depthRenderBuffer深度缓冲区,因为画的是立体的东东 , 视图显示错误
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    // 为 color renderbuffer 分配存储空间
    [self.mContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.mLayer];
    // 拿到宽和高
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
    // depth renderbuffer
    glGenRenderbuffers(1, &_depthRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _width, _height);
    // Framebuffers
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    // Framebuffers bind color renderbuffer and depth renderbuffer
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER, _depthRenderBuffer);
    // 切换到color renderbuffer
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);

    // Check FBO satus
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Error: Frame buffer is not completed.");
        exit(1);
    }
}

- (BOOL)setupShader
{
    GLuint vertShader, fragShader;
    NSURL *vertShaderURL, *fragShaderURL;

    self.program = glCreateProgram();
    vertShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }

    glAttachShader(self.program, vertShader);
    glAttachShader(self.program, fragShader);
    
    glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "textureCoord");
    // Link the program.
    if (![self linkProgram:self.program]) {
        NSLog(@"Failed to link program: %d", self.program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (self.program) {
            glDeleteProgram(self.program);
            self.program = 0;
        }
        
        return NO;
    }
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(self.program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(self.program, fragShader);
        glDeleteShader(fragShader);
    }
    return YES;
}


- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (GLuint)loadTextureWithImageName:(NSString *)imageName
{
    CGImageRef imageRef = [UIImage imageNamed:imageName].CGImage;
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetWidth(imageRef);
    
    GLubyte *data = (GLubyte *)calloc(width * height * 4, sizeof(GLubyte));
    
    CGContextRef contextRef = CGBitmapContextCreate(data, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(contextRef);
    CGImageRelease(imageRef);
    
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLfloat)width , (GLfloat)height , 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    free(data);
    
    return texture;
}

- (void)render
{
    //计算转动角度
    self.earthRotationAngleDegrees += 360.f / 60.f;
    self.moonRotationAngleDegrees += 360.f / 60.f / SceneDaysPerMoonOrbit;
    
    glEnable(GL_DEPTH_TEST);
    glClearColor(0.2, 0.3,0.4, 1.0);
    
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat x = self.frame.origin.x;
    CGFloat y = self.frame.origin.y;
    CGFloat w = self.frame.size.width;
    CGFloat h = self.frame.size.height;
    glViewport(x * scale, y * scale, w * scale, h * scale);
    
    glUseProgram(self.program);
    // ----------------------------- 绘制地球 -----------------------------//

    glBindTexture(GL_TEXTURE_2D, _earthTexture);
    glUniform1i(_samplerTexture, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, _ballVBO);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 3, GL_FLOAT, GL_FALSE, sizeof(float) * 3 , 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, _ballTextcoord);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE,sizeof(float) * 2, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    KSMatrix4 projectionMatrix;
    ksMatrixLoadIdentity(&projectionMatrix);
    //正交投影
//    ksOrtho(&projectionMatrix, -1.f * w / h, 1.f * w / h, -1.f, 1.f, 1.f, 10.f);
    //透视投影
    ksPerspective(&projectionMatrix, 60.f, w / h, 1.f, 10.f);
    glUniformMatrix4fv(_projectionMatrix, 1, GL_FALSE, &projectionMatrix.m[0][0]);
    
    KSMatrix4 earthMatrix = [self earthMartix];
    glUniformMatrix4fv(_modleViewMatrix, 1, GL_FALSE, &earthMatrix.m[0][0]);
    
    glDrawArrays(GL_TRIANGLES, 0, sphereNumVerts);
    
    // ----------------------------- 绘制月球 -----------------------------//
    
    glBindBuffer(GL_ARRAY_BUFFER, _ballVBO);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 3, GL_FLOAT, GL_FALSE, sizeof(float) * 3 , 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, _ballTextcoord);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE,sizeof(float) * 2, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glBindTexture(GL_TEXTURE_2D, _moonTexture);
    
    KSMatrix4 moonMatrix = [self moonMartix];
    glUniformMatrix4fv(_modleViewMatrix, 1, GL_FALSE, &moonMatrix.m[0][0]);
    
    glDrawArrays(GL_TRIANGLES, 0, sphereNumVerts);

    [self.mContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (KSMatrix4)earthMartix
{
    KSMatrix4 modelViewMatrix = [self getBaseModelViewMatrix];

    //倾斜
    KSMatrix4 rotateMatrix;
    ksMatrixLoadIdentity(&rotateMatrix);
    ksRotate(&rotateMatrix, -SceneEarthAxialTiltDeg, 1.f, 0.f, 0.f);
    ksMatrixMultiply(&modelViewMatrix, &rotateMatrix, &modelViewMatrix);
    // 自转
    KSMatrix4 rotateMatrix2;
    ksMatrixLoadIdentity(&rotateMatrix2);
    ksRotate(&rotateMatrix2, self.earthRotationAngleDegrees, 0.f, 1.f, 0.f);
    ksMatrixMultiply(&modelViewMatrix, &rotateMatrix2, &modelViewMatrix);
    return modelViewMatrix;
}

- (KSMatrix4)moonMartix
{
    KSMatrix4 modelViewMatrix = [self getBaseModelViewMatrix];
    // 设置公转
    KSMatrix4 rotateMarix1;
    ksMatrixLoadIdentity(&rotateMarix1);
    ksRotate(&rotateMarix1, self.moonRotationAngleDegrees, 0.0, 1.0, 0.0);
    ksMatrixMultiply(&modelViewMatrix, &rotateMarix1, &modelViewMatrix);
    // 平移
    KSMatrix4 totateMatrix2;
    ksMatrixLoadIdentity(&totateMatrix2);
    ksTranslate(&totateMatrix2, 0.0, 0.0, SceneMoonDistanceFromEarth);
    ksMatrixMultiply(&modelViewMatrix, &totateMatrix2, &modelViewMatrix);
    // 缩放
    KSMatrix4 scaleMatrix;
    ksMatrixLoadIdentity(&scaleMatrix);
    ksScale(&scaleMatrix, SceneMoonRadiusFractionOfEarth, SceneMoonRadiusFractionOfEarth, SceneMoonRadiusFractionOfEarth);
    ksMatrixMultiply(&modelViewMatrix, &scaleMatrix, &modelViewMatrix);
    // 自转
    KSMatrix4 rotateMatrix;
    ksMatrixLoadIdentity(&rotateMatrix);
    ksRotate(&rotateMatrix, self.moonRotationAngleDegrees, 0.f, 1.f, 0.f);
    ksMatrixMultiply(&modelViewMatrix, &rotateMatrix, &modelViewMatrix);
    return modelViewMatrix;
}

- (KSMatrix4)getBaseModelViewMatrix
{
    KSMatrix4 modelViewMatrix;
    ksMatrixLoadIdentity(&modelViewMatrix);
    ksTranslate(&modelViewMatrix, 0.0, 0.0, -4.0);
    return modelViewMatrix;
}

@end
