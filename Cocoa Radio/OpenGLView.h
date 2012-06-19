//
//  OpenGLView.h
//  Forest Map NCD
//
//  Created by William Dillon on 11/24/06.
//  Copyright 2006 VIA Computing. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OpenGL/gl.h"

@class OpenGLController;

@interface OpenGLView : NSOpenGLView
{
	IBOutlet OpenGLController *controller;

	NSOpenGLContext *glContext;

	bool initialized;
}

@property (readonly) NSOpenGLContext *glContext;

@end
