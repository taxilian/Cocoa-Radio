//
//  CSDRAppDelegate.m
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#define CSDRAPPDELEGATE_M
#import "CSDRAppDelegate.h"
#undef  CSDRAPPDELEGATE_M

#import <rtl-sdr/RTLSDRDevice.h>
#import <Accelerate/Accelerate.h>
#import <vecLib/vForce.h>
#import <mach/mach_time.h>

#import "CSDRSpectrumView.h"
#import "CSDRWaterfallView.h"
#import "dspRoutines.h"

NSString *CocoaSDRRawDataNotification  = @"CocoaSDRRawDataNotification";
NSString *CocoaSDRFFTDataNotification  = @"CocoaSDRFFTDataNotification";
NSString *CocoaSDRBaseBandNotification = @"CocoaSDRBaseBandNotification";

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
    
    if(result.realp == NULL || result.imagp == NULL ) {
        printf( "\nmalloc failed to allocate memory for the FFT.\n");
        return nil;
    }

    // Forward FFT (2048 elements log2 = 11
    vDSP_fft_zop ( setup, &input, 1, &result, 1, 11, FFT_FORWARD );
    
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

- (void)broadcastData:(NSData *)data
{
    // Get a stable copy of the sessions
    NSArray *tempSessions;
    @synchronized(sessions) {
        tempSessions = [sessions copy];
    }
    
    // Send the data to every session (asynch)
    for (NetworkSession *session in tempSessions) {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
//        ^{
            [session sendData:data];
//        });
    }
}

- (void)broadcastDict:(NSDictionary *)dict
{
    // Convert the complex split data into interleaved
    int count = [dict[@"real"] length] / sizeof(float);
    const float *real = [dict[@"real"] bytes];
    const float *imag = [dict[@"imag"] bytes];
    NSMutableData *data = [[NSMutableData alloc] initWithLength:count * sizeof(float) * 2];
    float *complex = [data mutableBytes];
    for (int i = 0; i < count; i++) {
        complex[i * 2 + 0] = real[i];
        complex[i * 2 + 1] = imag[i];
    }

    // Send the data
    [self broadcastData:data];
}

- (void)readLoop
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [device resetEndpoints];
    
    float *buffer = malloc(2048 * 2 * sizeof(float));
    
    do {
        @autoreleasepool {
            // Perform the read (2048 samples, one byte for I and Q)
            NSData *resultData = [device readSychronousLength:4096];
            if (resultData == nil) {
                NSApplication *app = [NSApplication sharedApplication];
                [app stop:self];
            }

            [self broadcastData:resultData];
            
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
            NSDictionary *complexRaw = @{ @"real" : realData,
                                          @"imag" : imagData };

//            // Send the the data at this stage for testing
//            [self broadcastDict:complexRaw];
            
            // Down convert
//            float LO = [[self waterfallView] tuningValue];
//            __block NSDictionary *baseBand;
//            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                baseBand = freqXlate(complexRaw, LO, 2048000);
//            });
            
            // Low-pass filter
//            __block NSDictionary *filtered;
//            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                filtered = [IFFilter filterDict:baseBand];
//            });

            // Quadrature demodulation
//            __block NSData *demodulated;
//            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                demodulated = quadratureDemod(filtered, 1., 0.);
//            });
            
            // Audio Frequency filter
//            __block NSData *audio;
//            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                audio = [AFFilter filterData:demodulated];
//            });
            
            // The resultData is new data from the device
            // Create a notification with the raw data
//            [center postNotificationName:CocoaSDRRawDataNotification
//                                  object:complexRaw];
            
            // Schedule an FFT of the new data
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSDictionary *fftDict = [self complexFFTOnDict:complexRaw];
//                NSDictionary *fftDict = [self complexFFTOnDict:baseBand];
//                NSDictionary *fftDict = [self complexFFTOnDict:filtered];

                // Make an empty imaginary array for demodulated info (real only)
//                NSData *emptyArray = [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
//                NSDictionary *demodDict = @{ @"real" : demodulated, @"imag" : emptyArray };
//                NSDictionary *fftDict = [self complexFFTOnDict:demodDict];
                
                [center postNotificationName:CocoaSDRFFTDataNotification
                                      object:fftDict];
            });
            
//            // Schedule a downconversion and filter
//            // The active demodulator will subscribe to this notification
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                NSData *baseBand = [self computeBaseBand:resultData];
//                [center postNotificationName:CocoaSDRBaseBandNotification
//                                      object:baseBand];
//            });
        }
    } while (true);
        
    free(buffer);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setTuningValue:144.370];
    [self setBottomValue:0.];
    [self setRange:1.];
    [self setAverage:16];
 
    IFFilter = [[CSDRlowPassComplex alloc] init];
    [IFFilter setBandwidth:90000];
    [IFFilter setSkirtWidth:20000];
    [IFFilter setSampleRate:2048000];
    [IFFilter setGain:1.];
    _IFbandwidth = 90;
    
    AFFilter = [[CSDRlowPassFloat alloc] init];
    [AFFilter setBandwidth:75000];
    [AFFilter setSkirtWidth:20000];
    [AFFilter setSampleRate:2048000];
    [AFFilter setGain:1.];
    _AFbandwidth = 75;
    
    // Instanciate an RTL SDR device (choose the first)
    NSArray *deviceList = [RTLSDRDevice deviceList];
    if ([deviceList count] == 0) {
        // Display an error and close
        NSAlert *alert = [NSAlert alertWithMessageText:@"No device found"
                                         defaultButton:@"Close"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Cocoa Radio was unable find any devices."];

        // Wait for the user to click it
        [alert runModal];
        
        // Shut down the app
        NSApplication *app = [NSApplication sharedApplication];
        [app stop:self];
        return;
    }

    // If there's more than one device, we should provide UI to
    // select the desired device.
    
    device = [[RTLSDRDevice alloc] initWithDeviceIndex:0];
    if (device == nil) {
        // Display an error and close
        NSAlert *alert = [NSAlert alertWithMessageText:@"Unable to open device"
                                         defaultButton:@"Close"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Cocoa Radio was unable to open the selected device."];
        
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
    [[self spectrumView] initialize];
    
    // Create the network server
    netServer = [[NetworkServer alloc] init];
    [netServer setDelegate:self];
    [netServer openWithPort:1234];
    sessions = [[NSMutableArray alloc] init];
    [netServer acceptInBackground];
        
    return;
}

#pragma mark -
#pragma mark Network delegate routines

-(void)NetworkServer:(NetworkServer *)server
          newSession:(NetworkSession *)session
{
    [session setDelegate:self];
    [sessions addObject:session];
    NSLog(@"Got client: %@", [session hostname]);
}

- (void)sessionTerminated:(NetworkSession *)session
{
    NSLog(@"Terminated client: %@", [session hostname]);
    [sessions removeObject:session];
}

#pragma mark -
#pragma mark Getters and Setters

- (float)tuningValue
{
    return tuningValue;
}

- (float)loValue
{
    return loValue;
}

- (void)setLoValue:(float)newLoValue
{
    [device setCenterFreq:(newLoValue * 1000000)];
    loValue = [device centerFreq];
    
    float tValue = loValue + [[self waterfallView] tuningValue];
    [self setTuningValue:tValue / 1000000.];
}

- (void)setTuningValue:(float)newTuningValue
{
//    [[self tuningField] setFloatValue:newTuningValue];
    tuningValue = newTuningValue;
    return;
}

- (float)IFbandwidth
{
    return _IFbandwidth;
}

- (void)setIFbandwidth:(float)bandwidth
{
    if (_IFbandwidth == bandwidth) {
        return;
    }
    
    // Make sure we're smaller than the nyquist limit
    if (bandwidth >= 1024000 ) {
        return;
    }
    
    _IFbandwidth = bandwidth;
    
    [IFFilter setBandwidth:_IFbandwidth * 1000];
}

- (float)AFbandwidth
{
    return _AFbandwidth;
}

- (void)setAFbandwidth:(float)bandwidth
{
    if (_AFbandwidth == bandwidth) {
        return;
    }
    
    // Make sure we're smaller than the nyquist limit
    if (bandwidth >= 1024000 ) {
        return;
    }
    
    _AFbandwidth = bandwidth;
    
    [AFFilter setBandwidth:_AFbandwidth * 1000];
}

@end
