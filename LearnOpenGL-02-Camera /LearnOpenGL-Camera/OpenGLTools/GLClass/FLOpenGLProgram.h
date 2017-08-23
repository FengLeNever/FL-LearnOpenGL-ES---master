//
//  FLOpenGLProgram.h
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/22.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>

@interface FLOpenGLProgram : NSObject

- (id)initWithVertexShaderFilename:(NSString *)vShaderFilename
            fragmentShaderFilename:(NSString *)fShaderFilename;

- (BOOL)linkProgram;
- (void)useProgram;

- (void)addAttribute:(NSString *)attributeName;
- (GLuint)attributeIndex:(NSString *)attributeName;
- (GLuint)uniformIndex:(NSString *)uniformName;

@end
