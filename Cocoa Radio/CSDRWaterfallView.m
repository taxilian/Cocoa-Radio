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
    pixel[3] = value;//  * CHAR_MAX;
    
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
    
    // Subscribe to FFT notifications
    NSNotificationCenter *center;
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(fftNotification:)
                   name:CocoaSDRFFTDataNotification object:nil];
}

/*
- (void)initShaders
{
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
    
    const GLchar *shaderText = [shaderString cStringUsingEncoding:NSUTF8StringEncoding];
    
    // Create ID for shader
    shader = glCreateShader(GL_FRAGMENT_SHADER);
    
    // Define shader text
    GLint length = (GLint)strlen(shaderText);
    glShaderSource(shader, 1, &shaderText, &length);
    
    // Compile shader
    glCompileShader(shader);
    
    // Associate shader with program
    program = glCreateProgram();
    glAttachShader(program, shader);
    
    // Link program
    glLinkProgram(program);
    
    // Validate program
    glValidateProgram(program);
    
    // Check the status of the compile/link
    GLint logLen = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
    if(logLen > 0)
    {
        // Show any errors as appropriate
        GLchar *log = malloc(logLen);
        glGetProgramInfoLog(program, logLen, &logLen, log);
        fprintf(stderr, "Prog Info Log: %s\n", log);
        free(log);
    }
    
    glUseProgram(program);
    // Retrieve all uniform locations that are determined during link phase
    glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &numUniforms);
    GLint error = glGetError();
    NSLog(@"Error getting uniform: %d", error);

    numUniforms = [uniforms count];
    
    if (uniformIDs == nil) {
        uniformIDs = malloc(sizeof(GLint) * numUniforms);
    } else {
        uniformIDs = realloc(uniformIDs, sizeof(GLint) * numUniforms);
    }
    
    for(int i = 0; i < numUniforms &&
        i < [uniforms count]; i++)
    {
        const GLchar *uniformString = [[uniforms objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding];
        uniformIDs[i] = glGetUniformLocation(program, uniformString);
        GLint error = glGetError();
        NSLog(@"Error getting uniform: %d", error);
    }
    
    // Retrieve all attrib locations that are determined during link phase
    glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES, &numAttributes);
    numAttributes = [attributes count];
    if (attributeIDs == nil) {
        attributeIDs = malloc(sizeof(GLint) * numUniforms);
    } else {
        attributeIDs = realloc(attributeIDs, sizeof(GLint) * numUniforms);
    }
    
    for(int i = 0; i < numAttributes &&
        i < [attributes count]; i++)
    {
        attributeIDs[i] = glGetAttribLocation(program, [[attributes objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    glUseProgram(0);
}
*/

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

    // Create arrays for the uniforms and attribute names
//    uniforms = @[ @"persistance", @"texture" ];
//    attributes = nil;

//    [self initShaders];

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
//    bzero(blankImage, sizeof(blankImage));
    for (int i = 0; i < HEIGHT; i++) {
        for (int j = 0; j < WIDTH; j++) {
            // Color cube
            blankImage[i*WIDTH*4 + j*4 + 1] = i;//*255 / HEIGHT;
            blankImage[i*WIDTH*4 + j*4 + 2] = j;//*255 / WIDTH;
            blankImage[i*WIDTH*4 + j*4 + 3] = 1.;//*255;
            blankImage[i*WIDTH*4 + j*4 + 4] = 1.;//*255;

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
            magBytes[i] = log10f(magBytes[i]);
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
//    glClear(GL_COLOR_BUFFER_BIT);

    if (!initialized) {
        return;
    }

    glBindTexture( GL_TEXTURE_2D, textureID );
    
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
    [shader setIntValue:3
             forUniform:@"persistance"];
    [shader setIntValue:currentLine
             forUniform:@"currentLine"];
    
    [shader setIntValue:HEIGHT
             forUniform:@"height"];

    [shader setFloatValue:[[self appDelegate] bottomValue]
               forUniform:@"bottomValue"];

    [shader setFloatValue:[[self appDelegate] range]
               forUniform:@"range"];
    
    [shader setIntValue:[[self appDelegate] average]
             forUniform:@"average"];
    
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













































