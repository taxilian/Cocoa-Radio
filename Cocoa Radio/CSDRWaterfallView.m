//
//  CSDRWaterfallView.m
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import "CSDRWaterfallView.h"
#import "OpenGLView.h"
#import "CSDRAppDelegate.h"

#define WIDTH  2048
#define HEIGHT 4096

@implementation CSDRWaterfallView

@synthesize currentLine;
@synthesize textureID;
@synthesize tuningValue;

void
rainbow(float pixel[4], float value)
{
	float rgb[3] = {0., 0., 0.};
    
    if (value > 0.) {
        // b -> c
        rgb[0] = 0.;
        rgb[1] = 4. * ( value - (0./4.) );
        rgb[2] = 1.;
    }
    
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
    
	pixel[0] = rgb[0];// * CHAR_MAX;
	pixel[1] = rgb[1];// * CHAR_MAX;
	pixel[2] = rgb[2];// * CHAR_MAX;
    pixel[3] = value; //  * CHAR_MAX;
    
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
        NSOpenGLPFAMultisample,
        NSOpenGLPFASampleBuffers, (NSOpenGLPixelFormatAttribute)1,
        NSOpenGLPFASamples, (NSOpenGLPixelFormatAttribute)4,
        (NSOpenGLPixelFormatAttribute)nil };

    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
    
	textureCurrent = NO;
    currentLine = 0;
    
    // Use 4 component texture (RGBA)
	textureBytes = malloc(WIDTH * HEIGHT * 4 * sizeof(float));
    
    // Create a slices array
    slices = [[NSMutableArray alloc] initWithCapacity:HEIGHT];
}

- (void)initGL
{
    initialized = NO;
    return;
}

-(void)initialize
{
    if (initialized) {
        return;
    } else {
        initialized = YES;
    }

// Read the shader from file
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *shaderURL = [bundle URLForResource:@"waterfallShader"
                                withExtension:@"ogl"];
    
    NSError *nsError = nil;
    NSString *shaderString = [NSString stringWithContentsOfURL:shaderURL
                                                      encoding:NSUTF8StringEncoding
                                                         error:&nsError];
    
    if (shaderString == nil) {
        if (nsError != nil) {
            NSLog(@"Unable to open shader file: %@", [nsError localizedDescription]);
        }
        
        return;
    }
    shader = [[ShaderProgram alloc] initWithVertex:nil
                                       andFragment:shaderString];
    
// Set black background
	glClearColor(0., 0., 0., 1.);
	
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
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST  );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST  );

    unsigned char *blankImage = malloc(sizeof(float) * 4 * WIDTH * HEIGHT);
    for (int i = 0; i < HEIGHT; i++) {
        for (int j = 0; j < WIDTH; j++) {
            // Color cube
            blankImage[i*WIDTH*4 + j*4 + 0] = i;//*255 / HEIGHT;
            blankImage[i*WIDTH*4 + j*4 + 1] = j;//*255 / WIDTH;
            blankImage[i*WIDTH*4 + j*4 + 2] = 1.;//*255;
            blankImage[i*WIDTH*4 + j*4 + 3] = 1.;//*255;

            // Black
//            blankImage[i*WIDTH*4 + j*4 + 1] = 0;
//            blankImage[i*WIDTH*4 + j*4 + 2] = 0;
//            blankImage[i*WIDTH*4 + j*4 + 3] = 0;
        }
    }
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_FLOAT, blankImage);
    free(blankImage);
    
    glTexEnvf( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );
	glBindTexture(  GL_TEXTURE_2D, 0 );
    
}

- (void)draw
{

    if (!initialized) {
        glClearColor(0., 0., 0., 1.);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }

    glBindTexture( GL_TEXTURE_2D, textureID );

    NSData *newSlice = [[self appDelegate] fftData];
    if (newSlice) {
        if (currentLine == HEIGHT) {
            currentLine = 0;
        } else {
            currentLine++;
        }
        
        const float *rawBuffer = [newSlice bytes];
        float *pixels = malloc(sizeof(float) * WIDTH * 4);
        
        float bottomValue = [[self appDelegate] bottomValue];
        float range = [[self appDelegate] range];
        
        for (int i = 0; i < WIDTH; i++) {
            float zeroCorrected = rawBuffer[i] - bottomValue;
            float scaled = zeroCorrected / range;

            rainbow(&pixels[i*4], scaled);
            pixels[i*4 + 3] = rawBuffer[i];
        }
        
        // Replace the oldest line in the texture
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, currentLine, WIDTH, 1, GL_RGBA, GL_FLOAT, pixels);
        
        free(pixels);
        newSlice = nil;
    }

    [shader bind];

    // Set the uniforms
    [shader setIntValue:3                                  forUniform:@"persistance"];
    [shader setIntValue:currentLine                        forUniform:@"currentLine"];
    [shader setIntValue:HEIGHT                             forUniform:@"height"];
    [shader setIntValue:[[self appDelegate] average]       forUniform:@"average"];
    [shader setFloatValue:[[self appDelegate] bottomValue] forUniform:@"bottomValue"];
    [shader setFloatValue:[[self appDelegate] range]       forUniform:@"range"];
    
    glBegin( GL_QUADS ); {
		glColor3f( 0., 1., 0. );

        float top = (float)currentLine / (float)HEIGHT;
        float bot = top + 1.;
        float left = 0.;
        float right = 1.;

        glTexCoord2d( left,  top );
		glVertex2f(   -1.,   -1.);
        
		glTexCoord2d( left,  bot );
		glVertex2f(   -1.,   1.);
        
		glTexCoord2d( right, bot );
		glVertex2f(   1.,    1.);
        
		glTexCoord2d( right, top );
		glVertex2f(   1.,    -1.);
	} glEnd();
    
    [shader unBind];
    glBindTexture( GL_TEXTURE_2D, 0 );
	
	glBegin( GL_LINES ); {
		glColor3f( 1., 0., 0. );
		glVertex2f( [self sliderValue], -1);
		glVertex2f( [self sliderValue],  1);
	} glEnd();
    
}

- (void)update
{
    [openGLView setNeedsDisplay:YES];
}

#pragma mark
#pragma mark User Interface Logic
- (IBAction) sliderUpdate:(id)sender
{
	sliderValue = ([sender floatValue] - 1) * -1;
	[openGLView setNeedsDisplay: YES];
    
	return;
}

- (void)mouseDownLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags
{
    // A right-mouse click is interpreted as a "pan" command
    // useful for changing the tuning of the device, while tracking
    // with the LO.  It is HIGHLY likely that the audio will skip
    
    // A left-mouse click is a re-tuning of the LO according to the
    // location of the click.
    float width = [openGLView bounds].size.width;
    float normalized = location.x / width;
    [self setSliderValue:(normalized * 2) - 1];
    
    // Calculate the tuned frequency and send it to the appdelegate
    float LO = [[self appDelegate] loValue];
    float tunedFreq = (normalized * [self sampleRate]) - ([self sampleRate] / 2);
    
    tuningValue = tunedFreq;
    
    tunedFreq += LO;
    [[self appDelegate] setTuningValue:tunedFreq / 1000000];
    
}

- (void)mouseDraggedLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags
{
    float width = [openGLView bounds].size.width;
    float normalized = location.x / width;
    [self setSliderValue:(normalized * 2) - 1];
    
    // Calculate the tuned frequency and send it to the appdelegate
    float LO = [[self appDelegate] loValue];
    float tunedFreq = (normalized * [self sampleRate]) - ([self sampleRate] / 2);
    
    tuningValue = tunedFreq;

    tunedFreq += LO;
    [[self appDelegate] setTuningValue:tunedFreq / 1000000];

    return;
}

@end
