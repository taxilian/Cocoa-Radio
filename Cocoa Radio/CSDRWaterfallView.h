//
//  CSDRWaterfallView.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import <Cocoa/Cocoa.h>
#import "OpenGLController.h"
#import "ShaderProgram.h"

#define TEXTURE_TYPE GL_TEXTURE_2D
//#define TEXTURE_TYPE GL_TEXTURE_RECTANGLE_ARB

@class CSDRAppDelegate;

@interface CSDRWaterfallView : OpenGLController
{
    bool initialized;
    
    // This value sets the location of the line for current tuning
	float sliderValue;
    float tuningValue;
	float sampleRate;
    
    // These ivars maintain OpenGL state
	bool textureCurrent;
	unsigned int textureID;
	unsigned char *textureBytes;
    unsigned int currentLine;

    ShaderProgram *shader;
    
    // This array contains the last spectrum slices
    // The slices are NSData arrays of floats from 0. to 1.
    NSMutableArray *slices;
}

@property (readwrite) IBOutlet CSDRAppDelegate *appDelegate;
@property (readwrite) float sliderValue;
@property (readwrite) float sampleRate;

@property (readwrite) float tuningValue;

@property (readonly) unsigned int textureID;
@property (readonly) unsigned int currentLine;

- (void)initialize;
- (IBAction) sliderUpdate:(id)sender;

- (void)update;

@end
