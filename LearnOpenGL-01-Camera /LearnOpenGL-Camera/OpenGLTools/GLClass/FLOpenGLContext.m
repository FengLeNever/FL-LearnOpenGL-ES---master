//
//  FLOpenGLContext.m
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/22.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import "FLOpenGLContext.h"
#import <GLKit/GLKit.h>

@interface FLOpenGLContext ()


@end

@implementation FLOpenGLContext

+(instancetype)shareGLContext
{
    static dispatch_once_t onceToken;
    static FLOpenGLContext *mGLContext = nil;

    dispatch_once(&onceToken, ^{
        mGLContext = [[[self class] alloc] init];
    });
    
    return mGLContext;
}

- (void)useAsCurrentContext;
{
    if ([EAGLContext currentContext] != self.mContext)
    {
        [EAGLContext setCurrentContext:self.mContext];
    }
}

- (EAGLContext *)mContext
{
    if (_mContext == nil) {
        _mContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (_mContext == nil) {
            NSLog(@"alloc Context error ...");
        }
        if (![EAGLContext setCurrentContext:_mContext]) {
            NSLog(@"set CurrentContext error ...");
        }
    }
    return _mContext;
}

- (void)presentBufferForDisplay
{
    [[FLOpenGLContext shareGLContext] useAsCurrentContext];
    [self.mContext presentRenderbuffer:GL_RENDERBUFFER];
}


@end
