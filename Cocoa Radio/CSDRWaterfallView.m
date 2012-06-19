//
//  CSDRWaterfallView.m
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRWaterfallView.h"
#import "OpenGLView.h"

#define WIDTH  2048
#define HEIGHT 2048

@implementation CSDRWaterfallView

void
rainbow(unsigned char pixel[4], float value)
{
	float rgb[3];
    //	value = value/100.;
    
	// b -> c
	rgb[0] = 0.;
	rgb[1] = 4. * ( value - (0./4.) );
	rgb[2] = 1.;
	
	if( value >= .25 ) {
		// c -> g
		rgb[0] = 0.;
		rgb[1] = 1.;
		rgb[2] = 1. - 4. * ( value - (1./4.) );
	}
	
	if( value >= .50 ) {
		// g -> y
		rgb[0] = 4. * ( value - (2./4.) );
		rgb[1] = 1.;
		rgb[2] = 0.;
	}
	
	if( value >= .75 ) {
		// y -> r
		rgb[0] = 1.;
		rgb[1] = 1. - 4. * ( value - (3./4.) );
		rgb[2] = 0.;
	}
	
    if (value >= 1.) {
		rgb[0] = 1.;
		rgb[1] = 1.;
		rgb[2] = 1.;
    }
    
	pixel[0] = rgb[0] * CHAR_MAX;
	pixel[1] = rgb[1] * CHAR_MAX;
	pixel[2] = rgb[2] * CHAR_MAX;	
    pixel[3] = CHAR_MAX;
    
	return;
}

#pragma mark -
#pragma mark Init and bookkeeping methods
+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
NSOpenGLPixelFormatAttribute attributes [] = {
    NSOpenGLPFAWindow,
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFAAccumSize, 32,
    NSOpenGLPFADepthSize, 16,
    (NSOpenGLPixelFormatAttribute)nil };

return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
    
	textureCurrent = NO;
    currentLine = 0;
    
    // Use 4 component texture (RGBA)
	textureBytes = (unsigned char *)malloc(WIDTH * HEIGHT * 4);
    
    // Create a slices array
    slices = [[NSMutableArray alloc] initWithCapacity:HEIGHT];
    
    // Subscribe to FFT notifications
    NSNotificationCenter *center;
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(fftNotification:)
                   name:CocoaSDRFFTDataNotification object:nil];
}

- (void)initGL
{
    // Set black background
	glClearColor(1.0, 0.0, 0.0, 1.0);
	
    // Set viewing mode
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1., -1.0, 1., -1., 1.);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

    // Set blending characteristics
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Set line width
	glLineWidth( 1.5 );
	
	glDisable( GL_DEPTH_TEST );
    glEnable( GL_TEXTURE_2D );

    // Get a texture ID
	glGenTextures( 1, (GLuint*)&textureID );
    
    // Set texturing parameters
	glBindTexture(  GL_TEXTURE_2D, textureID );
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR  );
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR  );
//	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
//	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
    
    unsigned char *blankImage = malloc(sizeof(unsigned int) * 4 * WIDTH * HEIGHT);
//    bzero(blankImage, sizeof(blankImage));
    for (int i = 0; i < HEIGHT; i++) {
        for (int j = 0; j < WIDTH; j++) {
            blankImage[i*WIDTH*4 + j*4 + 1] = i*255 / HEIGHT;
            blankImage[i*WIDTH*4 + j*4 + 2] = j*255 / WIDTH;
            blankImage[i*WIDTH*4 + j*4 + 3] = 255;
            blankImage[i*WIDTH*4 + j*4 + 4] = 255;
        }
    }
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, blankImage);
    free(blankImage);
    
    glTexEnvf( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );
	glBindTexture(  GL_TEXTURE_2D, 0 );
    
}

- (void)fftNotification:(NSNotification *)notification
{
    static int counter = 0;

    NSDictionary *fftData = (NSDictionary *)[notification object];
    const float *realData = (const float *)[fftData[@"real"] bytes];
    const float *imagData = (const float *)[fftData[@"imag"] bytes];

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
        
        for (int i = 0; i <  (WIDTH/2); i++) {
            realBuffer[i + (WIDTH/2)] = realData[i] / 200.;
            imagBuffer[i + (WIDTH/2)] = imagData[i] / 200.;
        }
        
        counter++;
    } else if (counter < 33) {
        for (int i = 0; i <= (WIDTH/2); i++) {
            realBuffer[i] += realData[i + (WIDTH/2)] / 200.;
            imagBuffer[i] += imagData[i + (WIDTH/2)] / 200.;
        }
        
        for (int i = 0; i <  (WIDTH/2); i++) {
            realBuffer[i + (WIDTH/2)] += realData[i] / 200.;
            imagBuffer[i + (WIDTH/2)] += imagData[i] / 200.;
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
        
        [self updateData:magBuffer];
    }
}

- (void)updateData:(id)data
{
    newSlice = data;
    [super updateData:self];
}

- (void)draw
{
//    glClearColor(0., 0., 0., 1.);
//    glClear(GL_COLOR_BUFFER_BIT);
//    return;

    if (newSlice) {
        if (currentLine == HEIGHT) {
            currentLine = 0;
        } else {
            currentLine++;
        }
        
        const float *rawBuffer = [newSlice bytes];
        unsigned char *pixels = malloc(sizeof(unsigned char) * WIDTH * 4);
        
        float bottomValue = [[self appDelegate] bottomValue];
        float range = [[self appDelegate] range];
        
        for (int i = 0; i < WIDTH; i++) {
            float zeroCorrected = rawBuffer[i] - bottomValue;
            float scaled = zeroCorrected / range;

            rainbow(&pixels[i*4], scaled);
        }
        
        // Replace the oldest line in the texture
        glBindTexture( GL_TEXTURE_2D, textureID );
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, currentLine, WIDTH, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        glBindTexture( GL_TEXTURE_2D, 0 );
        
        free(pixels);
        newSlice = nil;
    }
    
    glBindTexture( GL_TEXTURE_2D, textureID );
	glBegin( GL_QUADS ); {
		glColor3f( 1., 0., 0. );

        double top = (double)currentLine / (double)HEIGHT;
        double bot = top + 1.;
        
        glTexCoord2d( 0., top );
		glVertex2f(  -1.,  -1.);
        
		glTexCoord2d( 0., bot );
		glVertex2f(  -1.,   1.);
        
		glTexCoord2d( 1., bot );
		glVertex2f(   1.,   1.);
        
		glTexCoord2d( 1., top );
		glVertex2f(   1.,  -1.);
	} glEnd();
    
    glBindTexture( GL_TEXTURE_2D, 0 );
	
//	glBegin( GL_LINES ); {
//		glColor3f( 1., 0., 0. );
//		glVertex2f( sliderValue, -1);
//		glVertex2f( sliderValue,  1);
//	} glEnd();
    
	glFlush();
}

#pragma mark
#pragma mark User Interface Logic
- (IBAction) sliderUpdate:(id)sender
{
	sliderValue = ([sender floatValue] - 1) * -1;
	[openGLView setNeedsDisplay: YES];
    
	return;
}

- (void)mouseDraggedLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags
{
    return;
}

@end













































