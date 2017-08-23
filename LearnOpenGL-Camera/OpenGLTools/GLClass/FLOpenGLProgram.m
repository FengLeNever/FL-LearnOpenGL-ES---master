//
//  FLOpenGLProgram.m
//  LearnOpenGL-Camera
//
//  Created by FengLe on 2017/8/22.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import "FLOpenGLProgram.h"

@interface FLOpenGLProgram ()
{
    GLuint _vertShader;
    GLuint _fragShader;
}

@property (nonatomic, strong) NSMutableArray *attributes;

@property (nonatomic, strong) NSMutableArray *uniforms;

@property (nonatomic, assign) GLuint myProgram;

@end


@implementation FLOpenGLProgram

- (void)dealloc
{
    if (_vertShader) glDeleteShader(_vertShader);
    if (_fragShader) glDeleteShader(_fragShader);
    if (_myProgram) glDeleteProgram(_myProgram);
}

- (id)initWithVertexShaderString:(NSString *)vShaderString
            fragmentShaderString:(NSString *)fShaderString;
{
    if ((self = [super init]))
    {
        _attributes = [[NSMutableArray alloc] init];
        _uniforms = [[NSMutableArray alloc] init];
        _myProgram = glCreateProgram();
        
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

        if (![self compileShader:&_vertShader
                            type:GL_VERTEX_SHADER
                          string:vShaderString])
        {
            NSLog(@"Failed to compile vertex shader");
        }
        if (![self compileShader:&_fragShader
                            type:GL_FRAGMENT_SHADER
                          string:fShaderString])
        {
            NSLog(@"Failed to compile fragment shader");
        }
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        
        NSLog(@"compileShader in %f ms", linkTime * 1000.0);
        
        glAttachShader(_myProgram, _vertShader);
        glAttachShader(_myProgram, _fragShader);
    }
    
    return self;
}

- (id)initWithVertexShaderFilename:(NSString *)vShaderFilename
            fragmentShaderFilename:(NSString *)fShaderFilename;
{
    NSString *vertShaderPathname = [[NSBundle mainBundle] pathForResource:vShaderFilename ofType:@"vsh"];
    NSString *vertexShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    if (self = [self initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString]) {
    }
    return self;
}

// bind Attribute
- (void)addAttribute:(NSString *)attributeName
{
    if (![_attributes containsObject:attributeName])
    {
        [_attributes addObject:attributeName];
        glBindAttribLocation(_myProgram,(GLuint)[_attributes indexOfObject:attributeName], [attributeName UTF8String]);
    }
}

- (GLuint)attributeIndex:(NSString *)attributeName
{
    return (GLuint)[_attributes indexOfObject:attributeName];
}

- (GLuint)uniformIndex:(NSString *)uniformName
{
    return glGetUniformLocation(_myProgram, [uniformName UTF8String]);
}

- (void)useProgram
{
    glUseProgram(_myProgram);
}

#pragma mark - compile and link

- (BOOL)compileShader:(GLuint *)shader
                 type:(GLenum)type
               string:(NSString *)shaderString
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[shaderString UTF8String];
    if (!source)
    {
        NSLog(@"Failed to load shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);

    if (status != GL_TRUE)
    {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0)
        {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            NSLog(@"Failed to load shader - %s",log);
            free(log);
        }
        glDeleteShader(*shader);
    }
    
    return status == GL_TRUE;
}

- (BOOL)linkProgram
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    GLint status;
    
    glLinkProgram(_myProgram);
    
    glGetProgramiv(_myProgram, GL_LINK_STATUS, &status);
    
    if (status != GL_TRUE) {
        GLint logLength;
        glGetProgramiv(_myProgram, GL_INFO_LOG_LENGTH, &logLength);
        
        if (logLength > 0) {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetProgramInfoLog(_myProgram, logLength, &logLength, log);
            NSLog(@"Program link log:\n%s", log);
            free(log);
        }
        return NO;
    }
    
    if (_vertShader)
    {
        glDeleteShader(_vertShader);
        _vertShader = 0;
    }
    
    if (_vertShader)
    {
        glDeleteShader(_vertShader);
        _vertShader = 0;
    }
    
    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    
    NSLog(@"Linked Program in %f ms", linkTime * 1000.0);
    
    return YES;
}

@end
