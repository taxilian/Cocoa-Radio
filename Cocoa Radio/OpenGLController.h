//
//  OpenGLController.h
//  Forest Map NCD
//
//  Created by William Dillon on 11/24/06.
//  Copyright 2006 VIA Computing. All rights reserved.
//  Permission granted to Oregon State University for all use.
//

#import <Cocoa/Cocoa.h>
#import "OpenGLController.h"
#import "OpenGL/gl.h"

@class OpenGLView;
@class MyDocument;
@class AntiAlias;
@class Quaternion;

@interface OpenGLController : NSObject {
	IBOutlet OpenGLView *openGLView;
	IBOutlet NSDocument *myDocument;
	
	// Camera transforms
	Quaternion *trackBall;
	GLdouble cameraLoc[3];
	
	// Projection tramsform values
	GLdouble scale;
	GLfloat angleOfView, aspectRatio;
	AntiAlias *antiAlias;
	
	// Old mouse location for dragging
	NSPoint oldMouse;
}

@property (readonly) OpenGLView *openGLView;

// Get initialization parameters
+ (NSOpenGLPixelFormat *)defaultPixelFormat;

// UI IBActions and Events
- (IBAction)updateData:(id)sender;
- (void)mouseDownLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags;
- (void)mouseDraggedLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags;
- (void)scrollWheel:(NSEvent *)theEvent;

// Setters
- (void)setView:(id)view;
- (void)setAspectRatio:(GLfloat)aRatio;
- (void)setCameraLocationX:(float)x Y:(float)y Z:(float)z;

// OpenGL Methods and callbacks
- (void)initGL;
- (void)reshape:(NSRect)rect;
- (void)draw;

@end
