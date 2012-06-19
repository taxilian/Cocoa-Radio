//
//  OpenGLView.m
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "OpenGLView.h"
#import "OpenGLController.h"

@implementation OpenGLView

#pragma mark -
#pragma mark WM Init functions

// OpenGLView Initialization
-(id) initWithFrame: (NSRect) frameRect
{
    NSOpenGLPixelFormat *pixelFormat = [OpenGLView defaultPixelFormat];
	
    self = [super initWithFrame: frameRect pixelFormat: pixelFormat];
	initialized = NO;
	
    return self;
}

- (id)initWithFrame:(NSRect)frame pixelFormat:(NSOpenGLPixelFormat *)pixFmt
{
	self = [super initWithFrame:frame pixelFormat:pixFmt];
	if( self == nil ) {
		NSLog(@"Unable to initialize OpenGL view.");
		return self;
	}
	initialized = NO;
	
	return self;
}

- (id)initWithCoder:(NSCoder *)c
{
	self = [super initWithCoder:c];
	if( self == nil ) {
		NSLog(@"Unable to initialize OpenGL view.");
		return self;
	}
	initialized = NO;
	
	return self;
}

#pragma mark -
#pragma mark Application Specific Initialization
- (void)prepare
{
	// Get the current OpenGL context and make it active
	[self setPixelFormat:[[controller class] defaultPixelFormat]];
	glContext = [self openGLContext];
    
    GLint swapInterval = 1;
    [glContext setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];

	// Allow the OpenGLController to initialize the OpenGL State Machine if necessary
	if( initialized == NO )
		[controller initGL];
	initialized = YES;
	
	[self reshape];
	
	return;
}

#pragma mark -
#pragma mark Application Specific Callbacks
- (void)awakeFromNib
{
	[self prepare];
	[controller setView: self];
}

- (void)reshape
{
	NSRect rect = [self bounds];

	[glContext makeCurrentContext];
	[controller reshape:rect];
}

- (void)drawRect:(NSRect)rect
{
	[glContext makeCurrentContext];

	// Allow the OpenGLController to initialize the OpenGL State Machine if necessary
	if( initialized == NO )
		[controller initGL];
	initialized = YES;
	
	[controller draw];
	[glContext flushBuffer];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	// Get and filter the key modifiers
    NSUInteger modifierFlags = [theEvent modifierFlags];
	modifierFlags &= NSDeviceIndependentModifierFlagsMask;

	[controller mouseDownLocation:[self convertPoint:[theEvent locationInWindow] fromView:nil]
									Flags: modifierFlags];
	
	return;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	// Get and filter the key modifiers
    NSUInteger modifierFlags = [theEvent modifierFlags];
	modifierFlags &= NSDeviceIndependentModifierFlagsMask;

	[controller mouseDraggedLocation:[self convertPoint:[theEvent locationInWindow] fromView:nil]
							   Flags: modifierFlags];
	
	return;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	[controller scrollWheel:theEvent];
//	NSLog(@"Scroll wheel moved; (%f, %f, %f).\n", [event deltaX], [event deltaY], [event deltaZ] );
}



@end
