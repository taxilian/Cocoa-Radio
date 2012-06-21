//
//  ShaderProgram.h
//  HD Audio UI
//
//  Created by William Dillon on 6/19/08.
//  Copyright 2008 Oregon State University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OpenGL/gl.h"

@interface ShaderProgram : NSObject {
	GLuint theProgram, vertexShaderID, fragShaderID;
}

- (id)initWithVertex:(NSString *)vertexSource andFragment:(NSString *)fragmentSource;

- (GLuint)getUniformLocationForString:(NSString *)uniform;

- (void)setIntValue:(GLint)value forUniform:(NSString *)uniform;
- (void)setFloatValue:(GLfloat)value forUniform:(NSString *)uniform;
- (void)setDoubleValue:(GLdouble)value forUniform:(NSString *)uniform;

- (void)bind;
- (void)unBind;

@end
