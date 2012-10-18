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

#import <mach/mach_time.h>

#import "CSDRAudioDevice.h"
#import "CSDRRingBuffer.h"
#import "CSDRSpectrumView.h"
#import "CSDRWaterfallView.h"
#import "CSDRFFT.h"

#import "dspRoutines.h"
#import "dspprobes.h"

// This block size sets the frequency that the read loop runs
// sample rate / block size = block rate
#define BLOCKSIZE    20480
#define FFT_SIZE      2048

@implementation CSDRAppDelegate

@synthesize window = _window;

- (void)demodLoop
{
    [NSThread setThreadPriority:1.];
    
    do {
        @autoreleasepool {
            NSDictionary *complexRaw = nil;
            NSArray *blockArray = nil;
           
            // Attempt to get a block to process
            [demodCondition lock];
                int count = (int)[demodFIFO count];
                COCOARADIO_DEMODFIFO(count);

                // If there's no data, wait on the conditional variable
                if (count == 0) {
                    [demodCondition wait];
                }
            
                // If there's more than one block, collect all of it
                else if (count > 1) {
                    // Make a local copy of the FIFO
                    blockArray = [demodFIFO copy];
                    // and remove blocks out of the main FIFO
                    [demodFIFO removeAllObjects];
                    
                // Otherwise, there's exactly one.
                } else {
                    complexRaw = [demodFIFO objectAtIndex:0];
                    [demodFIFO removeObjectAtIndex:0];
                }
            [demodCondition unlock];
            
            if (blockArray) {
                [demodulatorLock lock];
                    for (NSDictionary *raw in blockArray) {
                        if (raw == nil)
                            continue;
                        NSData *audio = [demodulator demodulateData:raw];
                        [audioOutput bufferData:audio];
                    }
                [demodulatorLock unlock];
                blockArray = nil;
            }
            
            if (complexRaw) {
                // Process the block
                [demodulatorLock lock];
                NSData *audio = [demodulator demodulateData:complexRaw];
                [demodulatorLock unlock];
                
                // Send it to the audio device
                [audioOutput bufferData:audio];
                complexRaw = nil;
            }
        }
    } while (true);
}

- (void)processRFBlock:(NSData *)inputData withDuration:(float)duration
{
    @autoreleasepool {
        if (inputData == nil) {
            return;
        }
        
        // Get a reference to the raw bytes from the device
        const unsigned char *resultSamples = [inputData bytes];
        if (resultSamples == nil) {
            NSLog(@"Unable to get bytes from RF Data.");
            return;
        }
        
        // Derive the block size from the input (2, 1-byte samples per frame)
        int blocksize = [inputData length] / 2;
        
        // We need them to be floats (Real [Inphase] and Imaqinary [Quadrature])
        NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * blocksize];
        NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * blocksize];
        
        // All the vDSP routines (from the Accelerate framework)
        // need the complex data represented in a COMPLEX_SPLIT structure
        float *realp  = [realData mutableBytes];
        float *imagp  = [imagData mutableBytes];
        
        for (int i = 0; i < blocksize; i++) {
            realp[i] = (float)(resultSamples[i*2 + 0] - 127) / 128;
            imagp[i] = (float)(resultSamples[i*2 + 1] - 127) / 128;
        }

        // Process the samples for visualization with the FFT
        [fftProcessor addSamplesReal:realData imag:imagData];
        
        // Perform all the demodulation on the demodulation thread
        NSDictionary *complexRaw = @{ @"real" : realData, @"imag" : imagData };

        [demodCondition lock];
        int count = (int)[demodFIFO count];
        if (count > 100) {
            NSLog(@"WARNING: Demodulation isn't keeping up!");
        } else {
            [demodFIFO addObject:complexRaw];
        }
        [demodCondition signal];
        [demodCondition unlock];
    }
}

- (void)applyDefaultPreferences
{
    NSString *audioSampleRateKey = @"defaultAudioSampleRate";
    NSString *audioSampleRate = @"48000";

    NSString *radioSampleRateKey = @"defaultRadioSampleRate";
    NSString *radioSampleRate = @"2048000";

    // Set up the preference.
    CFPreferencesSetAppValue((__bridge CFStringRef)(audioSampleRateKey),
                             (__bridge CFPropertyListRef)(audioSampleRate),
                             kCFPreferencesCurrentApplication);

    CFPreferencesSetAppValue((__bridge CFStringRef)(radioSampleRateKey),
                             (__bridge CFPropertyListRef)(radioSampleRate),
                             kCFPreferencesCurrentApplication);

    // Write out the preference data.
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

- (void)getPreferences
{
    NSString *audioSampleRateKey = @"defaultAudioSampleRate";
    CFStringRef audioSampleRate;
    
    NSString *radioSampleRateKey = @"defaultRadioSampleRate";
    CFStringRef radioSampleRate;

    // Read the preferences
    audioSampleRate = (CFStringRef)CFPreferencesCopyAppValue((__bridge CFStringRef)(audioSampleRateKey),
                                                             kCFPreferencesCurrentApplication);
    radioSampleRate = (CFStringRef)CFPreferencesCopyAppValue((__bridge CFStringRef)(radioSampleRateKey),
                                                             kCFPreferencesCurrentApplication);
    
    afSampleRate = [(__bridge NSString *)audioSampleRate floatValue];
    rfSampleRate = [(__bridge NSString *)radioSampleRate floatValue];
    
    // When finished with value, you must release it
//    CFRelease(audioSampleRate);
//    CFRelease(radioSampleRate);
}

- (void)prepareRadioDevice
{
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
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//    [self getPreferences];
    afSampleRate = 48000;
    rfSampleRate = 1024000;
    int blocksize = 20480;

    [self prepareRadioDevice];
    
// Configure the FFT infrastructure for visualizations
    // It takes a while before the consumers of the FFT data wake up
    // the ring buffer smooths this and later data flow out.  We'll
    // use one second's worth of samples as the buffer capacity.
    fftProcessor = [[CSDRFFT alloc] initWithSize:FFT_SIZE];

// Setup the demodulation thread
    demodFIFO = [[NSMutableArray alloc] initWithCapacity:1];
    demodCondition = [[NSCondition alloc] init];
    demodThread = [[NSThread alloc] initWithTarget:self selector:@selector(demodLoop) object:nil];
    
// Create a new demodulator
    demodulatorLock = [[NSLock alloc] init];
    [self setDemodulationScheme:@"WBFM"];
    [self.demodulatorSelector setStringValue:@"WBFM"];

// Apply some additional preferences now that we're ready
    [self setLoValue:144.190];
    [self setTuningValue:144.390];
    [self setBottomValue:-1.];
    [self setRange:3.];
    [self setAverage:16];
    
// Prepare the waterfall and spectrum display classes
    [[self waterfallView] setSampleRate:rfSampleRate];
    [[self waterfallView] initialize];
    // Setup the shared context for the spectrum and waterfall views
    [[self spectrumView] shareContextWithController:[self waterfallView]];
    [[self spectrumView] initialize];
    
// Setup the audo output device
    audioOutput = [[CSDRAudioOutput alloc] initWithRate:afSampleRate];
    if (![audioOutput prepare]) {
        NSLog(@"Unable to start the audio device");
        NSApplication *app = [NSApplication sharedApplication];
        [app stop:self];
    }
    
    // Set the buffer level maximum value
    [self.bufferLevel setMaxValue:audioOutput.ringBuffer.capacity];
    
// Begin asynchronously reading from the device
    // The following warning can be ignored.  There is a retain cycle
    // but the objects in question live for the duration of the app.
    block = ^(NSData *resultData, float duration) {
        CSDRAppDelegate *delegate = self;
        [delegate processRFBlock:resultData withDuration:duration];};
    [device resetEndpoints];
    [device readAsynchLength:blocksize * 2
                   withBlock:block];
    
    [demodThread start];
    
// Setup a timer to set needs redisplay on all views
    viewTimer = [NSTimer timerWithTimeInterval:(1.0f/60.0f) target:self selector:@selector(animationTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:viewTimer forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:viewTimer forMode:NSEventTrackingRunLoopMode]; // ensure timer fires during resize
    return;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    return;
}

#pragma mark Extra stuff
- (void)audioAvailable:(NSNotification *)notification
{
    return;
}

- (void)animationTimer:(NSTimer *)timer
{
    static float bufferAverage = 0;
    
    // Update the power level
    float rfPower = demodulator.rfPower;
    if (isnormal(rfPower)) {
        if (rfPower > self.powerLevel.maxValue) {
            self.powerLevel.maxValue = rfPower;
            self.powerLevel.warningValue = rfPower;
            self.squelch.maxValue = rfPower;
        }
        
        if (rfPower < self.powerLevel.minValue) {
            self.powerLevel.minValue = rfPower;
            self.squelch.minValue = rfPower;
        }
        
        [self.powerLevel setFloatValue:demodulator.rfPower];
    }
    
    // Update the buffer level
    float buffLevel = audioOutput.ringBuffer.fillLevel;
    bufferAverage = (bufferAverage * .9) + (buffLevel * .1);
    self.bufferLevel.floatValue = bufferAverage;
    
    [self.waterfallView update];
    [self.spectrumView  update];
}

- (IBAction)showProperties:(id)sender
{
//    NSBundle *mainBundle = [NSBundle mainBundle];

//    NSDictionary *options = nil;
//    NSArray *objects = [mainBundle loadNibNamed:@"preferences"
//                                          owner:self
//                                        options:options];
}

- (IBAction)squelchChanged:(NSSlider *)sender;
{
    self.demodulator.squelch = [sender floatValue];
}

#pragma mark -
#pragma mark Getters and Setters

- (float)tuningValue
{
    float deviceFreq = [device centerFreq] / 1000000.;
    return [demodulator centerFreq] / 1000000. + deviceFreq;
}

- (float)loValue
{
    float deviceFreq = [device centerFreq];
    return deviceFreq / 1000000.;
}

- (void)setLoValue:(float)newLoValue
{
    [device setCenterFreq:(newLoValue * 1000000)];
    [audioOutput markDiscontinuity];
    
    [self setTuningValue:[demodulator centerFreq] / 1000000. + newLoValue];
}

// Tuning value provided in MHz
- (void)setTuningValue:(float)newTuningValue
{
    float deviceFreq  = [device centerFreq] / 1000000.;
    float demodCenter = newTuningValue - deviceFreq;

    // Tuning value expected is Hz.
    [demodulator setCenterFreq:demodCenter * 1000000];
    
    // Update the waterfall
    [self.waterfallView setTuningValue:demodCenter];
    
    return;
}

- (IBAction)changeIFbandwidth:(NSSlider *)sender
{
    float value = sender.floatValue;
    demodulator.ifBandwidth = value;

    NSString *bwString = [NSString stringWithFormat:@"%1.1f", value / 1000];
    [self.ifBandwidthField setStringValue:bwString];
}

- (IBAction)changeAFbandwidth:(NSSlider *)sender
{
    float value = sender.floatValue;
    demodulator.afBandwidth = value;

    NSString *bwString = [NSString stringWithFormat:@"%1.1f", value / 1000];
    [self.afBandwidthField setStringValue:bwString];
}

- (CSDRDemod *)demodulator
{
    return demodulator;
}

- (CSDRAudioOutput *)audioOutput
{
    return audioOutput;
}

- (NSString *)demodulationScheme
{
    return _demodulationScheme;
}

- (void)setDemodulationScheme:(NSString *)demodulationScheme
{
//    NSLog(@"Change scheme attempted.");
    _demodulationScheme = demodulationScheme;
    
    // Create a new demodulator
    CSDRDemod *newDemodulator = [CSDRDemod demodulatorWithScheme:demodulationScheme];
    newDemodulator.rfSampleRate = rfSampleRate;
    newDemodulator.afSampleRate = afSampleRate;

    // Setup the endpoints on the slider
    self.ifBandwidthSlider.maxValue = newDemodulator.ifMaxBandwidth;
    self.ifBandwidthSlider.minValue = newDemodulator.ifMinBandwidth;
    self.afBandwidthSlider.maxValue = newDemodulator.afMaxBandwidth;
    self.afBandwidthSlider.minValue = newDemodulator.afMinBandwidth;
    
    // Setup the defaults on the slider
    self.ifBandwidthSlider.floatValue = newDemodulator.ifBandwidth;
    self.afBandwidthSlider.floatValue = newDemodulator.afBandwidth;
    [self changeIFbandwidth:self.ifBandwidthSlider];
    [self changeAFbandwidth:self.afBandwidthSlider];
    
    // Change the demodulator atomically
    [demodulatorLock lock];
    demodulator = newDemodulator;
    [demodulatorLock unlock];

    [audioOutput discontinuity];
}

- (NSData *)fftData
{
    return [fftProcessor magBuffer];
}

@end
