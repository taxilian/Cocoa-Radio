//
//  CSDRWaterfallView.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OpenGLController.h"
#import "CSDRAppDelegate.h"

@interface CSDRWaterfallView : OpenGLController
{
    // This value sets the location of the line for current tuning
	float sliderValue;
	
    // These ivars maintain OpenGL state
	bool textureCurrent;
	unsigned int textureID;
	unsigned char *textureBytes;
    unsigned int currentLine;
    
    NSData *newSlice;
    
    // This array contains the last spectrum slices
    // The slices are NSData arrays of floats from 0. to 1.
    NSMutableArray *slices;
}

@property (readwrite) IBOutlet CSDRAppDelegate *appDelegate;

- (IBAction) sliderUpdate:(id)sender;

- (void)updateData:(id)data;
- (void)fftNotification:(NSNotificationCenter *)notification;

@end
