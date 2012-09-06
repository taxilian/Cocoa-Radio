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
#import <mach/mach_time.h>

#import "CSDRSpectrumView.h"
#import "CSDRWaterfallView.h"
#import "dspRoutines.h"

//#import "AudioDevice.h"
#import "CSDRAudioDevice.h"
#import "CSDRRingBuffer.h"

#import "delegateprobes.h"

// This block size sets the frequency that the read loop runs
// sample rate / block size = block rate
#define SAMPLERATE 2048000
#define BLOCKSIZE   204800

NSString *CocoaSDRRawDataNotification   = @"CocoaSDRRawDataNotification";
NSString *CocoaSDRFFTDataNotification   = @"CocoaSDRFFTDataNotification";
NSString *CocoaSDRBaseBandNotification  = @"CocoaSDRBaseBandNotification";
NSString *CocoaSDRAudioDataNotification = @"CocoaSDRAudioDataNotification";

@implementation CSDRAppDelegate

@synthesize window = _window;

- (void)fftBlock:(NSDictionary *)inDict
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    static float cumulative_remainder = 0.;

    NSData *realData = inDict[@"real"];
    NSData *imagData = inDict[@"imag"];
    
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
        NSDictionary *fftDict = complexFFTOnDict(complexRaw);
        
        // Convert the FFT format and average
        convertFFTandAverage(fftDict, fftBufferDict);
        
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
            
//            if (COCOARADIO_FFTCOUNTER_ENABLED()) {
//                COCOARADIO_FFTCOUNTER(cumulative * 100000);
//            }
        }
    }
    
    cumulative_remainder = cumulative;
}

- (void)readLoop
{
    [device resetEndpoints];

    NSMutableData *zeros = [[NSMutableData alloc] initWithLength:BLOCKSIZE * 2];
    
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
            if (resultSamples == nil) {
                NSLog(@"Problem getting samples from device.");
                resultSamples = [zeros bytes];
//                continue;
            }
            
            // We need them to be floats (Real [Inphase] and Imaqinary [Quadrature])
            NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * BLOCKSIZE];
            NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * BLOCKSIZE];
            
            // All the vDSP routines (from the Accelerate framework)
            // need the complex data represented in a COMPLEX_SPLIT structure
            float *realp  = [realData mutableBytes];
            float *imagp  = [imagData mutableBytes];

//            float average = 0.;
//            float max = -MAXFLOAT;
//            float min =  MAXFLOAT;
            // Convert the samples from bytes to floats between -1 and 1
            // and split them into seperate I and Q arrays
            for (int i = 0; i < BLOCKSIZE; i++) {
                realp[i] = (float)(resultSamples[i*2 + 0] - 127) / 128;
                imagp[i] = (float)(resultSamples[i*2 + 1] - 127) / 128;
                
//                average += realp[i];
//                average += imagp[i];
//                max = fmaxf(max, realp[i]);
//                max = fmaxf(max, imagp[i]);
//                min = fminf(min, realp[i]);
//                min = fminf(min, imagp[i]);
            }

//            NSLog(@"Input average: %f, min: %f, max: %f", average / (BLOCKSIZE * 2.), min, max);
            
            NSDictionary *complexRaw = @{ @"real" : realData,
                                          @"imag" : imagData };

            // Perform the FFT on another thread and broadcast the result
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                [self fftBlock:complexRaw];
            });
            
            // Perform all the operations on this block
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
            ^{
                // Demodulate the data
                NSData *audio = [demodulator demodulateData:complexRaw];

                [audioOutput bufferData:audio];
                // Notify that the results are available
//                NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
//                [center postNotificationName:CocoaSDRAudioDataNotification
//                                      object:audio];
            });
        }
    } while (true);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    rfSampleRate = SAMPLERATE;
    afSampleRate = 48000;
    
//    processQueue = dispatch_queue_create("com.us.alternet.cocoa-radio.processQueue",
//                                         DISPATCH_QUEUE_SERIAL);
    
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
    [device setSampleRate:rfSampleRate];
    
    // Setup the demodulator (for now, just WBFM)
    demodulator = [[CSDRDemodFM alloc] init];
    demodulator.rfSampleRate = rfSampleRate;
    demodulator.afSampleRate = afSampleRate;
    demodulator.ifBandwidth  = 90000;
    demodulator.ifSkirtWidth = 20000;
    demodulator.afBandwidth  = afSampleRate / 2;
    demodulator.afSkirtWidth = 20000;

    // Setup defaults
    [self setLoValue:144.390];
    [self setTuningValue:0.];
    [self setBottomValue:-1.];
    [self setRange:3.];
    [self setAverage:16];
    
    [[self waterfallView] setSampleRate:rfSampleRate];
    
    // Setup the audo output device
//    NSLog(@"Available audio devices:\n%@", [AudioDevice deviceDict]);
    audioOutput = [[CSDRAudioOutput alloc] init];
    float blockRate = SAMPLERATE / BLOCKSIZE;
    audioOutput.blockSize  = afSampleRate / blockRate;
    audioOutput.sampleRate = afSampleRate;
    if (![audioOutput prepare]) {
        NSLog(@"Unable to start the audio device");
        NSApplication *app = [NSApplication sharedApplication];
        [app stop:self];
    }
    [audioOutput start];
    
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
//    netServer = [[NetworkServer alloc] init];
//    [netServer setDelegate:self];
//    [netServer openWithPort:1234];
//    sessions = [[NSMutableArray alloc] init];
//    [netServer acceptInBackground];
    
    outData = [[NSMutableData alloc] init];
    
    // Subscribe to Audio notifications
    NSNotificationCenter *center;
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(audioAvailable:)
                   name:CocoaSDRAudioDataNotification object:nil];
    

    AudioBufferList *theBufferList;
    theBufferList = (AudioBufferList *)malloc(offsetof(AudioBufferList, mBuffers[2]));
    theBufferList->mNumberBuffers = 2;
    theBufferList->mBuffers[0].mNumberChannels = 1;
    theBufferList->mBuffers[0].mData =  malloc(480 * sizeof(float));
    theBufferList->mBuffers[0].mDataByteSize = (UInt32)480 * sizeof(float);
    theBufferList->mBuffers[1].mNumberChannels = 1;
    theBufferList->mBuffers[1].mData =  malloc(480 * sizeof(float));
    theBufferList->mBuffers[1].mDataByteSize = (UInt32)480 * sizeof(float);

    float buffer[4800];
    for (int i = 0; i < 4800; i++) {
        buffer[i] = i;
    }
    
    CSDRRingBuffer *ringBuffer = [[CSDRRingBuffer alloc] initWithCapacity:14400];

    // This should accurately simulate the audio operations.
    for (int i = 0; i < 20; i++) {
        // The stores/retreivals are 10:1
        [ringBuffer storeData:[NSData dataWithBytes:buffer length:4800 * sizeof(float)]];
        
        int last = 0;
        for (int j = 0; j < 10; j++) {
            [ringBuffer fetchFrames:480 into:theBufferList];
            
            // Check for errors
            float *floatVals = (float *)theBufferList->mBuffers[0].mData;
            for (int k = 0; k < 480; k++) {
                float expected = buffer[last];
                float received = floatVals[k];
                if (buffer[last] != floatVals[k]) {
                    NSLog(@"Found an error in the return.");
                }
                
                last = last + 1 % 4800;
            }
        }
    }
    
//    NSApplication *app = [NSApplication sharedApplication];
//    [app stop:self];
    
    return;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [outData writeToFile:@"/Users/wdillon/Desktop/out.raw" atomically:YES];
}

/*
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
*/

#pragma mark Extra stuff
- (void)audioAvailable:(NSNotification *)notification
{
//    [outData appendData:[notification object]];
}

#pragma mark -
#pragma mark Getters and Setters

- (float)tuningValue
{
    return [demodulator centerFreq] / 1000.;
}

- (float)loValue
{
    float deviceFreq = [device centerFreq];
    return deviceFreq / 1000000.;
}

- (void)setLoValue:(float)newLoValue
{
    [device setCenterFreq:(newLoValue * 1000000)];
}

// Tuning value provided in KHz
- (void)setTuningValue:(float)newTuningValue
{
    [demodulator setCenterFreq:newTuningValue * 1000000];
    
    return;
}

@end
