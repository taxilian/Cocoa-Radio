//
//  ShaderProgram.m
//  HD Audio UI
//
//  Created by William Dillon on 6/19/08.
//  Copyright 2008. All rights reserved. Licensed under the GPL v.2
//

#import "ShaderProgram.h"

@implementation ShaderProgram

#define BLOCK_SIZE 2048

- (id)initWithVertex:(NSString *)vertexSource andFragment:(NSString *)fragmentSource
{
	GLint status;
	const char *temp;
	
	unsigned int readBytes = 0;
	char shaderFileBuffer[BLOCK_SIZE];
	
	self = [super init];
	if( self == nil ) {
		NSLog(@"Unable in init parent");
		return self;
	}
	
	theProgram		= glCreateProgram();
	
// Pass vertex shader source to OpenGL
	if( vertexSource != nil ) {
        vertexShaderID	= glCreateShader( GL_VERTEX_SHADER );
		temp = [vertexSource UTF8String];
		glShaderSource( vertexShaderID, 1, &temp, NULL );

        // Compile the vertex shader
        glCompileShader( vertexShaderID );
        glGetShaderiv( vertexShaderID, GL_COMPILE_STATUS, &status );
        if( status != GL_TRUE ) {
            glGetShaderInfoLog( vertexShaderID, BLOCK_SIZE, (GLsizei*)&readBytes, shaderFileBuffer );
            NSLog(@"%s", shaderFileBuffer );
            return nil;
        }

    	glAttachShader( theProgram, vertexShaderID );
    }
		
	if (fragmentSource != nil) {
        fragShaderID	= glCreateShader( GL_FRAGMENT_SHADER );

        // Read the fragment shader file
        temp = [fragmentSource UTF8String];
        glShaderSource( fragShaderID, 1, &temp, NULL );		

        // Compile the fragment shader
        glCompileShader( fragShaderID );
        glGetShaderiv( fragShaderID, GL_COMPILE_STATUS, &status );
        if( status != GL_TRUE ) {
            glGetShaderInfoLog( fragShaderID, BLOCK_SIZE, (GLsizei*)&readBytes, shaderFileBuffer );
            NSLog(@"%s", shaderFileBuffer );
            return nil;
        }

        glAttachShader( theProgram, fragShaderID );
    }
	
// Link the shaders into a program
	glLinkProgram ( theProgram );
	glGetProgramiv( theProgram, GL_LINK_STATUS, &status );
	if( status != GL_TRUE ) {
		glGetProgramInfoLog( theProgram, BLOCK_SIZE, (GLsizei*)&readBytes, shaderFileBuffer );
		NSLog(@"Error while linking program:\n%s", shaderFileBuffer );
		return nil;
	}
	
// Validate and check to validate
	glValidateProgram( theProgram );
	glGetProgramiv( theProgram, GL_VALIDATE_STATUS, &status );
	if( status != GL_TRUE ) {
		glGetProgramInfoLog( theProgram, BLOCK_SIZE, (GLsizei*)&readBytes, shaderFileBuffer );
		NSLog(@"Error while validating program:\n%s", shaderFileBuffer );
		return nil;
	}
	
	NSLog(@"Shader Loaded, Compiled and Linked.");

	return self;
}

- (GLuint)getUniformLocationForString:(NSString *)uniform
{
	return glGetUniformLocation( theProgram, [uniform UTF8String] );
}

- (void)setIntValue:(GLint)value forUniform:(NSString *)uniform
{
	glUniform1i([self getUniformLocationForString:uniform], value);
}

- (void)setFloatValue:(GLfloat)value forUniform:(NSString *)uniform
{
	glUniform1f([self getUniformLocationForString:uniform], value);
}

- (void)setDoubleValue:(GLdouble)value forUniform:(NSString *)uniform
{
	glUniform1f([self getUniformLocationForString:uniform], value);
}

- (void)bind
{
	glUseProgram( theProgram );
}

- (void)unBind
{
	glUseProgram( 0 );

}

@end
