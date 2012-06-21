//
//  CSDRWaterfallView.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OpenGLController.h"
#import "CSDRAppDelegate.h"
#import "ShaderProgram.h"

@interface CSDRWaterfallView : OpenGLController
{
    bool initialized;
    
    // This value sets the location of the line for current tuning
	float sliderValue;
	float sampleRate;
    
    // These ivars maintain OpenGL state
	bool textureCurrent;
	unsigned int textureID;
	unsigned char *textureBytes;
    unsigned int currentLine;

    ShaderProgram *shader;
    
//    GLuint program;
//    GLuint shader;
//    GLint numUniforms;
//    GLint *uniformIDs;
//    NSArray *uniforms;
    
//    GLint numAttributes;
//    GLint *attributeIDs;
//    NSArray *attributes;

    NSData *newSlice;
    
    // This array contains the last spectrum slices
    // The slices are NSData arrays of floats from 0. to 1.
    NSMutableArray *slices;
}

@property (readwrite) IBOutlet CSDRAppDelegate *appDelegate;
@property (readwrite) float sliderValue;
@property (readwrite) float sampleRate;

@property (readonly) unsigned int textureID;
@property (readonly) unsigned int currentLine;

- (IBAction) sliderUpdate:(id)sender;

- (void)initialize;

- (void)updateData:(id)data;
- (void)fftNotification:(NSNotificationCenter *)notification;

@end
