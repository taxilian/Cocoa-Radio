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

#import "delegateprobes.h"

// This block size sets the frequency that the read loop runs
// sample rate / block size = block rate
#define SAMPLERATE 2048000
#define BLOCKSIZE  1024000
//#define ACCELERATE

NSString *CocoaSDRRawDataNotification  = @"CocoaSDRRawDataNotification";
NSString *CocoaSDRFFTDataNotification  = @"CocoaSDRFFTDataNotification";
NSString *CocoaSDRBaseBandNotification = @"CocoaSDRBaseBandNotification";

@implementation CSDRAppDelegate

@synthesize window = _window;

// This function takes an input dictionary with a real and imaginary
// key that contains an NSData encapsulated array of floats.
// There are input samples, each is a full complex number.
// The output is also complex numbers in interleaved format.
// The desired output is the posative/negative frequency format
//- (NSDictionary *)complexFFTOnData:(NSDictionary *)inData
//
// The number of input samples must be a power of two.
//
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
    
    // There aren't (to my knowledge) any const versions of this class
    // therefore, we have to cast with the knowledge that these arrays
    // are really consts.
    COMPLEX_SPLIT input;
    input.realp  = (float *)[inDict[@"real"] bytes];
    input.imagp  = (float *)[inDict[@"imag"] bytes];
    
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
    
    // Find the number log2 number of samples
    vDSP_fft_zop(setup, &input, 1, &result, 1, 11, FFT_FORWARD );
    
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

- (void)convertFFTandAverage:(NSDictionary *)inDict
{
    NSData *real = inDict[@"real"];
    NSData *imag = inDict[@"imag"];
    
    const float *realData = (const float *)[real bytes];
    const float *imagData = (const float *)[imag bytes];
    
    int width = [real length] / sizeof(float);
    
    float *realBuffer = [fftBufferDict[@"real"] mutableBytes];
    float *imagBuffer = [fftBufferDict[@"imag"] mutableBytes];
    
    // The format of the frequency data is:
    
    //  Positive frequencies | Negative frequencies
    //  [DC][1][2]...[n/2][NY][n/2]...[2][1]  real array
    //  [DC][1][2]...[n/2][NY][n/2]...[2][1]  imag array
    
    // We want the order to be negative frequencies first (descending)
    // And positive frequencies last (ascending)
    
    // Accumulate this data with what came before it, and re-order the values
    for (int i = 0; i <= (width/2); i++) {
        realBuffer[i] += realData[i + (width/2)] / 200.;
        imagBuffer[i] += imagData[i + (width/2)] / 200.;
    }
    
    for (int i = 0; i <  (width/2); i++) {
        realBuffer[i + (width/2)] += realData[i] / 200.;
        imagBuffer[i + (width/2)] += imagData[i] / 200.;
    }
}


- (void)broadcastData:(NSData *)data
{
    // Get a stable copy of the sessions
    NSArray *tempSessions;
    @synchronized(sessions) {
        tempSessions = [sessions copy];
    }
    
    if (COCOARADIO_SENDDATA_ENABLED()) {
        COCOARADIO_SENDDATA((int)[data length]);
    }
    
    // Send the data to every session (asynch)
    for (NetworkSession *session in tempSessions) {
        [session sendData:data];
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

- (void)processBlock:(NSDictionary *)inDict
{
    [self broadcastDict:inDict];
    /*
    // Down convert
    float LO = [[self waterfallView] tuningValue];
    __block NSDictionary *baseBand;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        baseBand = freqXlate(inDict, LO, 2048000);
    });
    
    // Low-pass filter
    __block NSDictionary *filtered;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        filtered = [IFFilter filterDict:baseBand];
    });
    
    // Quadrature demodulation
    __block NSData *demodulated;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        demodulated = quadratureDemod(filtered, 1., 0.);
    });
    
    // Audio Frequency filter
    __block NSData *audio;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        audio = [AFFilter filterData:demodulated];
    });
     */
}

- (void)readLoop
{
    __block float cumulative_remainder = 0.;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [device resetEndpoints];

    NSMutableData *tempReal = [[NSMutableData alloc] initWithLength:BLOCKSIZE * sizeof(float)];
    NSMutableData *tempImag = [[NSMutableData alloc] initWithLength:BLOCKSIZE * sizeof(float)];
    fftBufferDict = @{ @"real" : tempReal,
                       @"imag" : tempImag };
    
    do {
        @autoreleasepool {

            // The device provides single byte values for I and Q. We need two bytes per sample.
            NSData *resultData = [device readSychronousLength:BLOCKSIZE * 2];
            if (resultData == nil) {
                NSApplication *app = [NSApplication sharedApplication];
                [app stop:self];
            }

            if (COCOARADIO_DATARECEIVED_ENABLED()) {
                COCOARADIO_DATARECEIVED();
            }
            
            // Get a reference to the raw bytes from the device
            const unsigned char *resultSamples = [resultData bytes];
            
            // We need them to be floats (Real [Inphase] and Imaqinary [Quadrature])
            NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * BLOCKSIZE];
            NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * BLOCKSIZE];
            
            // All the vDSP routines (from the Accelerate framework)
            // need the complex data represented in a COMPLEX_SPLIT structure
            COMPLEX_SPLIT input;
            input.realp  = (float *)[realData mutableBytes];
            input.imagp  = (float *)[imagData mutableBytes];

            // Convert the samples from bytes to floats between -1 and 1
            // and split them into seperate I and Q arrays
#ifndef ACCELERATE
            for (int i = 0; i < BLOCKSIZE; i++) {
                input.realp[i] = (float)(resultSamples[i*2 + 0] - 127) / 128;
                input.imagp[i] = (float)(resultSamples[i*2 + 1] - 127) / 128;
            }
#else
            char *signedSamples = malloc(BLOCKSIZE * 2);
            for (int i = 0; i < BLOCKSIZE * 2; i++) {
                signedSamples[i] = resultSamples[i] - 127;
            }
            vDSP_vflt8(signedSamples + 0, 2, input.realp, 1, BLOCKSIZE);
            vDSP_vflt8(signedSamples + 1, 2, input.realp, 1, BLOCKSIZE);
            for (int i = 0; i < BLOCKSIZE; i++) {
                input.realp[i] = input.realp[i] / 128.;
                input.imagp[i] = input.imagp[i] / 128.;
            }
#endif

            // Perform the FFT on another thread and broadcast the result
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                // Split the block size into 2048-sized chunks.
                // Careful attention must be paid to ensure that the
                // correct amount of data is used for each frame period.
                
                int ffts = BLOCKSIZE / 2048;
                if (ffts * 2048 != BLOCKSIZE) {
                    NSLog(@"The block size isn't an even multiple of 2048.");
                    [NSApp close];
                }

                // FFT intervale and cumulative time
                float interval = 2048. / (float)SAMPLERATE;
                float cumulative = cumulative_remainder;
                
                // For each 2048 sample block, perform the FFT (to average)
                for (int i = 0; i < ffts; i++) {
                    int size = 2048 * sizeof(float);
                    NSRange range = NSMakeRange(i * size, size);
                    NSData *subsetReal = [realData subdataWithRange:range];
                    NSData *subsetImag = [imagData subdataWithRange:range];
                    
                    NSDictionary *complexRaw = @{ @"real" : subsetReal,
                                                  @"imag" : subsetImag };

                    // Perform the FFT
                    NSDictionary *fftDict = [self complexFFTOnDict:complexRaw];
                    
                    // Convert the FFT format and average
                    [self convertFFTandAverage:fftDict];
                    
                    // Attempt to track the cumulative time that the
                    // data represents.  Whenever it crosses a frame
                    // interval (assume 1/60 seconds) send the data
                    // to the UI and reset the averages.
                    cumulative += interval;
                    if (cumulative >= (1./60.)) {
                        // Process the data
                        [center postNotificationName:CocoaSDRFFTDataNotification
                                              object:fftBufferDict];
                        
                        // Discard the averaged data
                        [fftBufferDict[@"real"] resetBytesInRange:NSMakeRange(0, 2048 * sizeof(float))];
                        [fftBufferDict[@"imag"] resetBytesInRange:NSMakeRange(0, 2048 * sizeof(float))];

                        // Sleep for the duration (move from seconds to microseconds)
                        usleep(cumulative * 1000000.);
                        
                        // Keep the cumulative interval greater than 1/60th of a second.
                        cumulative = cumulative - (1./60.);
                        
                        if (COCOARADIO_FFTCOUNTER_ENABLED()) {
                            COCOARADIO_FFTCOUNTER(cumulative * 100000);
                        }
                    }
                }
                
                cumulative_remainder = cumulative;
            });

            NSDictionary *complexRaw = @{ @"real" : realData,
                                          @"imag" : imagData };
            
            // Perform all the operations on this block
            dispatch_async(processQueue, ^{
                [self processBlock:complexRaw];
            });
        }
    } while (true);
    
//    free(bufferReal);
//    free(bufferImag);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    processQueue = dispatch_queue_create("com.us.alternet.cocoa-radio.processQueue",
                                         DISPATCH_QUEUE_SERIAL);
    
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
