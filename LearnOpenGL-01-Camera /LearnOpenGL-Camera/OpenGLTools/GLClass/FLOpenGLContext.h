//
//  FLOpenGLContext.h
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/22.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>

@interface FLOpenGLContext : NSObject

@property (nonatomic, strong) EAGLContext *mContext;

+(instancetype)shareGLContext;

- (void)useAsCurrentContext;

- (void)presentBufferForDisplay;

@end
