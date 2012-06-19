//
//  OpenGLController.m
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "OpenGLController.h"
#import "OpenGLView.h"
//#import "Quaternion.h"

@implementation OpenGLController

- (void)awakeFromNib
{
	// Set camera transforms to some reasonable value
	angleOfView = 45;
	scale = 1.;
}

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
	NSLog(@"Creating a null pixel format: Probably not desired");
	
    NSOpenGLPixelFormatAttribute attributes [] = { (NSOpenGLPixelFormatAttribute)nil };
	
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

- (void)dealloc
{
	openGLView = nil;
}

- (void)initGL
{
	NSLog(@"NULL init GL");
	
	glClearColor( 0.0, 0.0, 0.0, 1.0 );
	
//	trackBall = [[Quaternion alloc] init];
	
	return;
}

- (void)draw
{
	NSLog(@"NULL draw");
	
	glClear( GL_COLOR_BUFFER_BIT );
	
	return;
}

- (void)reshape:(NSRect)rect
{
	glViewport(0, 0, rect.size.width, rect.size.height);
	
//	[trackBall screenResize];
	
	return;
}

#pragma mark -
#pragma mark Setter Methods
- (void)setView:(id)sender
{
	openGLView = sender;
}

- (void)setCameraLocationX:(float)x Y:(float)y Z:(float)z
{
	cameraLoc[0] = x;
	cameraLoc[1] = y;
	cameraLoc[2] = z;
}

- (void)setAspectRatio:(GLfloat)aRatio
{
	aspectRatio = aRatio;
}

#pragma mark -
#pragma mark User Interface logic
- (void)mouseDownLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags;
{
	oldMouse = location;

//	[trackBall mouseDown:location];
	
	return;
}

- (void)mouseDraggedLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags
{	
	// Calculate the delta of the mouse location
	NSPoint deltaMouse;
	
	// Calculate the mouse motion delta
	deltaMouse.x = (location.x - oldMouse.x);
	deltaMouse.y = (location.y - oldMouse.y);
	oldMouse = location;
	
	// No modifiers = Rotate camera
//	if( modifierFlags == 0 ) {
		// Use the trackball to rotate the camera
//		[trackBall mouseMotion:location];
		[openGLView setNeedsDisplay: YES];
//	}

/***** DISABLE CAMERA TRANSLATION FOR NOW *****/
	// Command + Alt = Translate Camera In Y dimension
//	if( (modifierFlags & NSCommandKeyMask) && (modifierFlags & NSAlternateKeyMask) ) {
//		cameraLoc[1] -= deltaMouse.y * 0.1;
//		NSLog(@"New camera location: %f, %f, %f", cameraLoc[0], cameraLoc[1], cameraLoc[2]);
//		[openGLView setNeedsDisplay: YES];
//	} 
//	
//	// Command = Translate Camera in XZ plane
//	else if( modifierFlags & NSCommandKeyMask ) {
//		cameraLoc[0] += deltaMouse.x * 0.5;		// Apply x-wise motion of the mouse to the camera
//		cameraLoc[2] -= deltaMouse.y * 0.5;		// Apply y-wise motion of the mouse to the camera's z value
//		NSLog(@"New camera location: %f, %f, %f", cameraLoc[0], cameraLoc[1], cameraLoc[1]);
//		[openGLView setNeedsDisplay: YES];
//	}
	
	return;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	scale += scale * [theEvent deltaY] / 100.;
	[openGLView setNeedsDisplay: YES];
}

- (IBAction)updateData:(id)sender
{
	[openGLView setNeedsDisplay: YES];
}

@end
