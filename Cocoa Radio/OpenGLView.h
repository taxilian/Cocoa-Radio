//
//  OpenGLView.h
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
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
