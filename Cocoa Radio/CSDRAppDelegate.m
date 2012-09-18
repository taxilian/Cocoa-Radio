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
#define BLOCKSIZE    40960
#define FFT_SIZE      2048

@implementation CSDRAppDelegate

@synthesize window = _window;

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
        
        // We need them to be floats (Real [Inphase] and Imaqinary [Quadrature])
        NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * BLOCKSIZE];
        NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * BLOCKSIZE];
        
        // All the vDSP routines (from the Accelerate framework)
        // need the complex data represented in a COMPLEX_SPLIT structure
        float *realp  = [realData mutableBytes];
        float *imagp  = [imagData mutableBytes];
        
        for (int i = 0; i < BLOCKSIZE; i++) {
            realp[i] = (float)(resultSamples[i*2 + 0] - 127) / 128;
            imagp[i] = (float)(resultSamples[i*2 + 1] - 127) / 128;
        }

        // Process the samples for visualization with the FFT
        [fftProcessor addSamplesReal:realData imag:imagData];
        
        // Perform all the operations on this block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
       ^{
           NSDictionary *complexRaw = @{ @"real" : realData,
                                         @"imag" : imagData };
           
            // Demodulate the data
           [demodulatorLock lock];
           NSData *audio = [demodulator demodulateData:complexRaw];
           [demodulatorLock unlock];

           [audioOutput bufferData:audio];
       });
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
    rfSampleRate = 2048000;

    [self prepareRadioDevice];
    
// Configure the FFT infrastructure for visualizations
    // It takes a while before the consumers of the FFT data wake up
    // the ring buffer smooths this and later data flow out.  We'll
    // use one second's worth of samples as the buffer capacity.
    fftProcessor = [[CSDRFFT alloc] initWithSize:FFT_SIZE];

// Setup the demodulator (for now, default to WBFM)
    demodulatorLock = [[NSLock alloc] init];
    demodulator = [[CSDRDemodWBFM alloc] initWithRFRate:rfSampleRate
                                                 AFRate:afSampleRate];

// Apply some additional preferences now that we're ready
    [self setLoValue:144.390];
    [self setTuningValue:0.];
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
    
// Begin asynchronously reading from the device
    // The following warning can be ignored.  There is a retain cycle
    // but the objects in question live for the duration of the app.
    block = ^(NSData *resultData, float duration) {
        CSDRAppDelegate *delegate = self;
        [delegate processRFBlock:resultData withDuration:duration];};
    [device resetEndpoints];
    [device readAsynchLength:BLOCKSIZE * 2
                   withBlock:block];
    
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
//    [fftProcessor updateMagnitudeData];
    [self.waterfallView update];
    [self.spectrumView  update];
}

- (IBAction)showProperties:(id)sender
{
    NSBundle *mainBundle = [NSBundle mainBundle];

    NSDictionary *options = nil;
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
    [audioOutput markDiscontinuity];
}

// Tuning value provided in KHz
- (void)setTuningValue:(float)newTuningValue
{
    [demodulator setCenterFreq:newTuningValue * 1000000];
    
    return;
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
    _demodulationScheme = demodulationScheme;
    
    // Create a new demodulator
    CSDRDemod *newDemodulator = [CSDRDemod demodulatorWithScheme:demodulationScheme];
    newDemodulator.rfSampleRate = rfSampleRate;
    newDemodulator.afSampleRate = afSampleRate;
    newDemodulator.afBandwidth  = afSampleRate / 2;

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
