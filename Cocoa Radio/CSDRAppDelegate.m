//
//  CSDRAppDelegate.m
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#define CSDRAPPDELEGATE_M
#import "CSDRAppDelegate.h"
#undef  CSDRAPPDELEGATE_M

#import <rtl-sdr/RTLSDRDevice.h>
#import <Accelerate/Accelerate.h>
#import "CSDRSpectrumView.h"
#import "CSDRWaterfallView.h"

NSString *CocoaSDRRawDataNotification = @"CocoaSDRRawDataNotification";
NSString *CocoaSDRFFTDataNotification = @"CocoaSDRFFTDataNotification";

@implementation CSDRAppDelegate

@synthesize window = _window;

// This function takes an input dictionary with a real and imaginary
// key that contains an NSData encapsulated array of floats.
// There are 2048 samples, each is a full complex number.
// The output is 2048 complex numbers in interleaved format.
// The desired output is the posative/negative frequency format
//- (NSDictionary *)complexFFTOnData:(NSDictionary *)inData
- (NSDictionary *)complexFFTOnDict:(NSDictionary *)inDict
{
    static FFTSetup setup = NULL;
    if (setup == NULL) {
        // Setup the FFT system (accelerate framework)
        setup = vDSP_create_fftsetup(11, FFT_RADIX2);
        if (setup == NULL)
        {      
            printf("\nFFT_Setup failed to allocate enough memory.\n");
            exit(0);
        }
    }
    
    COMPLEX_SPLIT input;
    input.realp  = [inDict[@"real"] mutableBytes];
    input.imagp  = [inDict[@"imag"] mutableBytes];

    // Allocate memory for the output operands and check its availability.
    // Results data are 2048 floats (I and Q)
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
    COMPLEX_SPLIT result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    if( input.realp == NULL ||
        input.imagp == NULL ||
       result.realp == NULL ||
       result.imagp == NULL ) {
        printf( "\nmalloc failed to allocate memory for the FFT section of the test.\n");
        exit(0);
    }

    // Forward FFT (2048 elements log2 = 11
    vDSP_fft_zop ( setup, &input, 1, &result, 1, 11, FFT_FORWARD );
    
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

- (void)readLoop
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [device resetEndpoints];
    
    do {
        @autoreleasepool {
            // Perform the read (2048 samples, one byte for I and Q)
            NSData *resultData = [device readSychronousLength:4096];
            if (resultData == nil) {
                NSApplication *app = [NSApplication sharedApplication];
                [app stop:self];
            }

            const uint8_t *resultSamples = [resultData bytes];
            
            // Results data are 2048 floats (I and Q)
            NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
            NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
            
            // Convert the samples from bytes to floats between -1 and 1
            // and split them into seperate I and Q arrays
            COMPLEX_SPLIT input;
            input.realp  = (float *)[realData mutableBytes];
            input.imagp  = (float *)[imagData mutableBytes];
            for (int i = 0; i < 2048; i++) {
                input.realp[i] = (float)(resultSamples[i*2 + 0] - 127) / 128;
                input.imagp[i] = (float)(resultSamples[i*2 + 1] - 127) / 128;
            }
            
            NSDictionary *complexData = @{ @"real" : realData,
                                           @"imag" : imagData};
            
            // The resultData is new data from the device
            // Create a notification with the raw data
            [center postNotificationName:CocoaSDRRawDataNotification
                                  object:complexData];
            
            // Schedule an FFT of the new data
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSDictionary *fftDict = [self complexFFTOnDict:complexData];
                [center postNotificationName:CocoaSDRFFTDataNotification
                                      object:fftDict];
            });
        }
    } while (true);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setTuningValue:144.370];
    [self setBottomValue:0.];
    [self setRange:1.];
    
    // Instanciate an RTL SDR device (choose the first)
    device = [[RTLSDRDevice alloc] initWithDeviceIndex:0];
    if (device == nil) {
        // Display an error and close
        NSAlert *alert = [NSAlert alertWithMessageText:@"Unable to open device"
                                         defaultButton:@"Close"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Cocoa Radio was unable to open the RTL Tuner, check its connection and try again."];
        // Wait for the user to click it
        [alert runModal];
        
        // Shut down the app
        NSApplication *app = [NSApplication sharedApplication];
        [app stop:self];
        return;
    }

    // Set the sample rate and tuning
    [device setSampleRate:2048000];
    [device setCenterFreq:tuningValue];
    
    [[self waterfallView] setSampleRate:2048000];
    
    // Create a thread for reading
    readThread = [[NSThread alloc] initWithTarget:self
                                         selector:@selector(readLoop)
                                           object:nil];
    [readThread start];
    
    // Setup the shared context for the spectrum and waterfall views
    [[self waterfallView] initialize];
    [[self spectrumView] shareContextWithController:[self waterfallView]];
    // Initialize the waterfall view to create the texture
    // Then the spectrum view
    [[self spectrumView] initialize];
    
    return;
}

- (float)tuningValue
{
//    return loValue + [[self waterfallView] tuningValue];
    return tuningValue;
}

- (float)loValue
{
    return loValue;
}

- (void)setLoValue:(float)loValue
{
    return;
}

- (void)setTuningValue:(float)newTuningValue
{
    [device setCenterFreq:(newTuningValue * 1000000)];
    tuningValue = [device centerFreq];
}

@end
