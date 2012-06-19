//
//  SpectrumView.m
//  Spectrum Analyzer
//
//  Created by William Dillon on 2/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRSpectrumView.h"
#import "CSDRAppDelegate.h"

#define WIDTH  2048
#define HEIGHT 2048

@implementation CSDRSpectrumView

@synthesize nativePixelsInGraph;

// This method determines the location of the point in screen space
// and rounds the value to yield pixel-aligned lines, which are sharp.
// The size field is only used to compute a half-pixel offset in the case
// of objects that are an odd number of pixels in size, so they fit perfectly.
- (NSPoint)pixelAlignPoint:(NSPoint)point withSize:(NSSize)size
{
    NSSize sizeInPixels = [self convertSizeToBase:size];
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
    
    NSPoint basePoint = [self convertPointToBase:point];
    basePoint.x = round(basePoint.x) + adjustmentInPixels.x;
    basePoint.y = round(basePoint.y) + adjustmentInPixels.y;
    
    return [self convertPointFromBase:basePoint];
}

- (void)viewBoundsChanged
{
    // Calculate native pixels in graph
    float borderWidth = 0;
    NSRect borderRect = NSInsetRect([self bounds],
                                    borderWidth,
                                    borderWidth);
    
    // Pixel-align the rect
    borderRect.origin = [self pixelAlignPoint:borderRect.origin
                                     withSize:NSMakeSize(1., 1.)];    
    
    // Assume that points=pixels for now (not true in HiRes mode)
    nativePixelsInGraph = borderRect.size;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

        // Listen to notifications of views frame being resized
        NSNotificationCenter *center;
        center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:NSViewFrameDidChangeNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:
         ^(NSNotification *event) {
             if ([[event object] isEqual:self]) {
                 [self viewBoundsChanged];
             }
         }];
        
        [self viewBoundsChanged];
        
        // Subscribe to FFT notifications
        center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(fftNotification:)
                       name:CocoaSDRFFTDataNotification object:nil];

    }
    
    return self;
}

#pragma mark -
#pragma mark Drawing code

// This method draws the horizontal gridlines.
// Each line is at exactly at 10 dB points.
- (void)drawHorizGridsInRect:(NSRect)rect
{
//    float heightPerDiv = rect.size.height / [controller vDevisions];
    float heightPerDiv = rect.size.height / 10.;
    NSBezierPath *path = [[NSBezierPath alloc] init];
    [[NSColor darkGrayColor] set];
    [path setLineWidth:1.];
    
//    for (int i = 0; i < [controller vDevisions]; i++) {
    for (int i = 0; i < 10.; i++) {
        NSPoint leftPoint  = NSMakePoint(rect.origin.x,
                                         i * heightPerDiv + rect.origin.y);
        NSPoint rightPoint = NSMakePoint(rect.origin.x + rect.size.width,
                                         i * heightPerDiv + rect.origin.y);
        
        leftPoint  = [self pixelAlignPoint:leftPoint  withSize:NSMakeSize(1., 1.)];
        rightPoint = [self pixelAlignPoint:rightPoint withSize:NSMakeSize(1., 1.)];
        
        [path moveToPoint:leftPoint];
        [path lineToPoint:rightPoint];
    }
    
    [path stroke];
}

- (void)drawVertGridsInRect:(NSRect)rect
{
    [[NSColor darkGrayColor] set];
    NSBezierPath *path = [NSBezierPath bezierPath];

    float deltaPixels = rect.size.width / 10.;
    for (int i = 1; i < 10; i++) {
        // iterate through the horizontal rules
        NSPoint topPoint    = NSMakePoint(i * deltaPixels + rect.origin.x,
                                          rect.origin.y + rect.size.height);
        NSPoint bottomPoint = NSMakePoint(i * deltaPixels + rect.origin.x,
                                          rect.origin.y);
        
        // Make the center line a little lower than the bottom line
        if (i == 5) {
            bottomPoint.y -= 5.;
        }
        
        topPoint    = [self pixelAlignPoint:topPoint    withSize:NSMakeSize(1., 1.)];
        bottomPoint = [self pixelAlignPoint:bottomPoint withSize:NSMakeSize(1., 1.)];
        
        [path moveToPoint:topPoint];
        [path lineToPoint:bottomPoint];
    }
    
    [path stroke];
}

- (void)drawDataInRect:(NSRect)rect
{
    // All this stuff doesn't change with the different "modes"
    int steps = WIDTH;
    const float *samples = [fftData bytes];
    
    float pixelsPerStep = (rect.size.width - 1) / steps;
    
    float bottomValue = [[self appDelegate] bottomValue];
    float range = [[self appDelegate] range];
    float pixelsPerUnit = rect.size.height / range;

    
    [[NSColor yellowColor] set];
    NSBezierPath *path = [[NSBezierPath alloc] init];
    [path setLineWidth:1.];
    
    // If pixels per step is less than one we're in "oversample" mode
    // If it's equal when we're in a 1-to-1 mode
    // If it's more than one we're in undersamples mode
    
    // Over sample mode works by finding the high and low values for each pixel
    // draw a line from the low value to the high at the pixel.  If it works
    // out that there is only one sample for the pixel.  It is both the high
    // and the low value.
    /*
    if (pixelsPerStep < .99) {
        bool starting = YES;
        int lastSample = 0;
        
        // Iterate through the pixels
        for (int i = 0; i < rect.size.width; i++) {
            float min =  FLT_MAX;
            float max = -FLT_MAX;
            
            // Accumulate min and maxes for all steps that fall within this pixel
            NSPoint thisPixel = [self pixelAlignPoint:NSMakePoint(rect.origin.x + i, 0.)
                                             withSize:NSMakeSize(1., 1.)];

            for (int j = lastSample; j < steps; j++) {
                // Assume that point = pixels (this is usually true)
                NSPoint testPixel = NSMakePoint(thisPixel.x + round((j - lastSample)*pixelsPerStep),
                                                thisPixel.y);
                
                // If we've left the pixel, break out and start again
                if (!NSEqualPoints(thisPixel, testPixel)) {
                    lastSample = j;
                    break;
                }
                
                // If the sample is NAN don't count it
                if (samples[i] == NAN) {
                    continue;
                }

                // Collect the minimum and maximum values
                float magnitude = samples[j];
                if (max < magnitude) max = magnitude;
                if (min > magnitude) min = magnitude;
            }
            
        // Draw a line from the minimum to maximum
            // Minimum pixel
            float unitSpan = (min - bottomValue) / range;
            float centeredPixel = unitSpan * (rect.size.height / 2.);
            float yMin = centeredPixel + rect.origin.y + (rect.size.height / 2.);
            // Maximum pixel
            unitSpan = (max - bottomValue) / range;
            centeredPixel = unitSpan * (rect.size.height / 2.);
            float yMax = centeredPixel + rect.origin.y + (rect.size.height / 2.);
            
            if (starting) {
                [path moveToPoint:NSMakePoint(thisPixel.x, yMin)];
                starting = NO;
            } else {
                [path lineToPoint:NSMakePoint(thisPixel.x, yMin)];
            }
            [path lineToPoint:NSMakePoint(thisPixel.x, yMax)];
        }
    }
    */
    if (false)
        NSLog(@"Do nothing");

    // One-to-one mode means that each sample is exactly a single pixel
    // Undersample mode works the same as one-to-on mode.
    else {
        for (int i = 0; i < steps; i++) {
            // Cycle through the points in the graph converting the dBs to pixels
            float x = i * pixelsPerStep + rect.origin.x;
            
            // If the sample is NAN don't draw it
            if (samples[i] == NAN) {
                [path moveToPoint:NSMakePoint(x, rect.origin.y)];
                continue;
            }
            
            // Set the range of the scale to be 0 < 1
            // First, move the input by the zero compensation
            float zeroCorrected = samples[i] - bottomValue;
            float scaled = zeroCorrected / range;
            float y = scaled * rect.size.height + rect.origin.y;
            
            // Devide the number of steps into the width.
            // Snap all points to device pixels.
//            float unitSpan = (samples[i] - bottomValue) / range;
//            float centeredPixel = unitSpan * (rect.size.height / 2.);
//            float y = centeredPixel + rect.origin.y + (rect.size.height / 2.);
            
            NSPoint point = [self pixelAlignPoint:NSMakePoint(x, y)
                                         withSize:NSMakeSize(1., 1.)];
            
            if (i == 0) {
                [path moveToPoint:point];
            } else {
                [path lineToPoint:point];
            }
        }
    }
    
    [path stroke];
    path = nil;
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

        fftData = magBuffer;
        
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor blackColor] set];

    NSBezierPath *framePath = [NSBezierPath bezierPathWithRect:[self bounds]];
    [framePath fill];
    
    float borderWidth = 0;
    NSRect borderRect = NSInsetRect([self bounds],
                                    borderWidth,
                                    borderWidth);

    // Pixel-align the rect
    borderRect.origin = [self pixelAlignPoint:borderRect.origin
                                     withSize:NSMakeSize(1., 1.)];    
    
    // Draw the vertical lines
    [self drawVertGridsInRect:borderRect];
    
    // Draw horizontal lines
    [self drawHorizGridsInRect:borderRect];
    
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:borderRect];
    [[NSColor whiteColor] set];
    [borderPath stroke];

    [self drawHorizGridsInRect:borderRect];
    
    // Draw the actual data
    if (fftData != nil) {
        [self drawDataInRect:borderRect];
    }
}

#pragma mark -
#pragma mark UI Code

@end
