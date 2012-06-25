//
//  SpectrumView.m
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRSpectrumView.h"
#import "CSDRAppDelegate.h"
#import "OpenGLView.h"
#import "OpenGLController.h"
#import "CSDRWaterfallView.h"

#define WIDTH  2048
#define HEIGHT 4096

#define H_GRID 10
#define V_GRID 10

@implementation CSDRSpectrumView

#pragma mark -
#pragma mark Init and bookkeeping methods
+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attributes [] = {
        NSOpenGLPFAWindow,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccumSize, 32,
        NSOpenGLPFADepthSize, 16,
        NSOpenGLPFAMultisample,
        NSOpenGLPFASampleBuffers, (NSOpenGLPixelFormatAttribute)1,
        NSOpenGLPFASamples, (NSOpenGLPixelFormatAttribute)4,
        (NSOpenGLPixelFormatAttribute)nil };
    
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

// This method determines the location of the point in screen space
// and rounds the value to yield pixel-aligned lines, which are sharp.
// The size field is only used to compute a half-pixel offset in the case
// of objects that are an odd number of pixels in size, so they fit perfectly.
- (NSPoint)pixelAlignPoint:(NSPoint)point withSize:(NSSize)size
{
    NSSize sizeInPixels = [openGLView convertSizeToBase:size];
    CGFloat halfWidthInPixels  = sizeInPixels.width * 0.5;
    CGFloat halfHeightInPixels = sizeInPixels.height * 0.5;
    
    // Is the width an odd number of pixels?
    NSPoint adjustmentInPixels = NSMakePoint(0., 0.);
    if (fabs(halfWidthInPixels - floor(halfWidthInPixels)) > 0.0001 ) {
        adjustmentInPixels.x = 0.5;
    } else {
        adjustmentInPixels.x = 0.;
    }
    
    // Is the height an odd number of pixels?
    if (fabs(halfHeightInPixels - floor(halfHeightInPixels)) > 0.0001 ) {
        adjustmentInPixels.y = 0.5;
    } else {
        adjustmentInPixels.y = 0.;
    }
    
    // This is the adjustment needed for odd or even sizes
    //    NSPoint adjustment = [self convertPointFromBase:adjustmentInPixels];
    
    NSPoint basePoint = [openGLView convertPointToBase:point];
    basePoint.x = round(basePoint.x) + adjustmentInPixels.x;
    basePoint.y = round(basePoint.y) + adjustmentInPixels.y;
    
    return [openGLView convertPointFromBase:basePoint];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
    
    // Subscribe to FFT notifications
    NSNotificationCenter *center;
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(fftNotification:)
                   name:CocoaSDRFFTDataNotification object:nil];
}

- (void)initGL
{
    initialized = NO;
    shader = nil;
}

-(void)initialize
{
    if (initialized) {
        return;
    } else {
        initialized = YES;
    }

// Create the shader program
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *vertURL = [bundle URLForResource:@"spectrumShader" withExtension:@"vert"];
    NSURL *fragURL = [bundle URLForResource:@"spectrumShader" withExtension:@"frag"];
    
    NSError *error = nil;
    NSString *vertString = [NSString stringWithContentsOfURL:vertURL encoding:NSUTF8StringEncoding error:&error];
    if (vertString == nil) {
        if (error != nil) {
            NSLog(@"Unable to open vertex file: %@", [error localizedDescription]);
        }
        
        return;
    }

    NSString *fragString = [NSString stringWithContentsOfURL:fragURL encoding:NSUTF8StringEncoding error:&error];
    if (fragString == nil) {
        if (error != nil) {
            NSLog(@"Unable to open fragment file: %@", [error localizedDescription]);
        }
        
        return;
    }

    shader = [[ShaderProgram alloc] initWithVertex:vertString
                                       andFragment:fragString];
    
    // Set RED background
	glClearColor(1.0, 0.0, 0.0, 1.0);
	
    // Set viewing mode
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0., 1., 0., 1., -1., 1.);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
    
    // Set blending characteristics
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // Set line width
	glLineWidth( 1. );

    // Setup the options
    glDisable( GL_DEPTH_TEST );
    glEnable( GL_TEXTURE_2D );

    // Load the texture from the waterfall display
    textureID = [[[self appDelegate] waterfallView] textureID];
    glBindTexture( GL_TEXTURE_2D, textureID );
    glTexEnvf( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );
    glBindTexture(GL_TEXTURE_2D, 0);
}

#pragma mark -
#pragma mark Drawing code

// This method draws the horizontal gridlines.
// Each line is at exactly at 10 dB points.
- (void)drawHorizGridsInRect:(NSRect)rect
{
    NSColor *lineColor = [[NSColor grayColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    double r, g, b, a;
    [lineColor getRed:&r green:&g blue:&b alpha:&a];

    for (int i = 0; i < H_GRID; i++) {
        glBegin(GL_LINES);
        glColor4d(r, g, b, a);
        
        float y = (1./ (float)H_GRID) * (float)i;
        
        glVertex2d(0., y);
        glVertex2d(1., y);
        
        glEnd();
    }
}

- (void)drawVertGridsInRect:(NSRect)rect
{
    NSColor *lineColor = [[NSColor grayColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    double r, g, b, a;
    [lineColor getRed:&r green:&g blue:&b alpha:&a];
    
    for (int i = 0; i < V_GRID; i++) {
        glBegin(GL_LINES);
        glColor4d(r, g, b, a);
        
        float x = (1./ (float)V_GRID) * (float)i;
        
        glVertex2d(x, 0.);
        glVertex2d(x, 1.);
        
        glEnd();
    }
}

- (void)drawDataInRect:(NSRect)rect
{
    // use a yellow line for the spectrum
    NSColor *lineColor = [[NSColor yellowColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    double r, g, b, a;
    [lineColor getRed:&r green:&g blue:&b alpha:&a];

// Because we're using an OpenGL texture for the data content,
// we can just specify a set of vertices, one per pixel
// evenly spaced across the view.  In the vertex shader, we'll
// move those vertices into the appropriate place according to
// the source data.

    // Clear any errors
    GLint error = glGetError();

    // Bind the shader
    [shader bind];

    // Bind the data texture
    glBindTexture(GL_TEXTURE_2D, textureID);

    // Get the current line (most recent) in the texture
    int currentLine = [[[self appDelegate] waterfallView] currentLine];
    
    // Set the uniforms
    [shader setIntValue:3
             forUniform:@"persistance"];

//    [shader setIntValue:currentLine
//             forUniform:@"line"];

    [shader setFloatValue:(float)currentLine / (float)HEIGHT
               forUniform:@"line"];
    
    [shader setIntValue:(float)HEIGHT
               forUniform:@"height"];

    [shader setIntValue:(float)WIDTH
             forUniform:@"width"];

    [shader setFloatValue:[[self appDelegate] bottomValue]
               forUniform:@"bottomValue"];
    
    [shader setFloatValue:[[self appDelegate] range]
               forUniform:@"range"];
    
    [shader setIntValue:[[self appDelegate] average]
             forUniform:@"average"];

    [shader setIntValue:0 forUniform:@"texture"];
    
    // Check for errors
    error = glGetError();
    if (error != GL_NO_ERROR) {
        NSLog(@"Got an error from OpenGL: %d", error);
    }
    
    // Begin drawing the lines for the spectrum
    glBegin(GL_LINE_STRIP);
    glColor4d(r, g, b, a);
    GLuint width = rect.size.width;
    for (int i = 0; i < width; i++) {
        float x = (1. / (float)width) * (float)i;
        
        // For debugging, we'll set X and Y to the same value
        // this means we should see a diagonal line
        glVertex2d(x, x);
    }
    glEnd();

    glBindTexture( TEXTURE_TYPE, 0 );
    [shader unBind];
    
    glFlush();
}

- (void)draw
{
    if (!initialized) {
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }
    
    NSColor *lineColor = [[NSColor blackColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    double r, g, b, a;
    [lineColor getRed:&r green:&g blue:&b alpha:&a];
    r = g = b = 0.;
    a = 1.;

    glClearColor(r, g, b, a);
//    glClear(GL_COLOR_BUFFER_BIT);
    
    // Color the background with a semi-opaque rect for persistance
    glColor4f(0., 0., 0., .125);
    glBegin(GL_QUADS);
    glVertex2d(0., 0.);
    glVertex2d(0., 1.);
    glVertex2d(1., 1.);
    glVertex2d(1., 0.);
    glEnd();
    
    float borderWidth = 0;
    NSRect borderRect = NSInsetRect([openGLView bounds],
                                    borderWidth,
                                    borderWidth);
    
    // Pixel-align the rect
    borderRect.origin = [self pixelAlignPoint:borderRect.origin
                                     withSize:NSMakeSize(1., 1.)];    
    
    // Draw the vertical lines
    [self drawVertGridsInRect:borderRect];
    
    // Draw horizontal lines
    [self drawHorizGridsInRect:borderRect];
    
    // Draw the actual data
    if (fftData != nil) {
        [self drawDataInRect:borderRect];
    }
}

- (void)fftNotification:(NSNotification *)notification
{
    static int counter = 0;
    
    NSDictionary *fftDataIn = (NSDictionary *)[notification object];
    const float *realData = (const float *)[fftDataIn[@"real"] bytes];
    const float *imagData = (const float *)[fftDataIn[@"imag"] bytes];
    
    static float realBuffer[WIDTH];
    static float imagBuffer[WIDTH];
    
    // The format of the frequency data is:
    
    //  Positive frequencies | Negative frequencies
    //  [DC][1][2]...[n/2][NY][n/2]...[2][1]  real array
    //  [DC][1][2]...[n/2][NY][n/2]...[2][1]  imag array
    
    // We want the order to be negative frequencies first (descending)
    // And positive frequencies last (ascending)
    
    // Accumulate this data with what came before it, and re-order the values
    if (counter == 0) {
        for (int i = 0; i <= (WIDTH/2); i++) {
            realBuffer[i] = realData[i + (WIDTH/2)] / 200.;
            imagBuffer[i] = imagData[i + (WIDTH/2)] / 200.;
        }
        
        for (int i = 0; i < (WIDTH/2); i++) {
            realBuffer[i +  (WIDTH/2)] = realData[i] / 200.;
            imagBuffer[i +  (WIDTH/2)] = imagData[i] / 200.;
        }
        
        counter++;
    } else if (counter < 33) {
        for (int i = 0; i <= (WIDTH/2); i++) {
            realBuffer[i] += realData[i + (WIDTH/2)] / 200.;
            imagBuffer[i] += imagData[i + (WIDTH/2)] / 200.;
        }
        
        for (int i = 0; i < (WIDTH/2); i++) {
            realBuffer[i +  (WIDTH/2)] += realData[i] / 200.;
            imagBuffer[i +  (WIDTH/2)] += imagData[i] / 200.;
        }
        
        counter++;
    } else {
        counter = 0;
        
        NSMutableData *magBuffer = [[NSMutableData alloc] initWithCapacity:WIDTH * sizeof(float)];
        float *magBytes = [magBuffer mutableBytes];
        
        // Compute the magnitude of the data
        for (int i = 0; i < WIDTH; i++) {
            magBytes[i] = sqrtf((realBuffer[i] * realBuffer[i]) +
                                (imagBuffer[i] * imagBuffer[i]));
        }

        fftData = magBuffer;
        
        [openGLView setNeedsDisplay:YES];
    }
}

#pragma mark -
#pragma mark UI Code

@end
