//
//  CSDRAppDelegate.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012). All rights reserved. Licensed under the GPL v.2
//

#import <Cocoa/Cocoa.h>

// Forward declaration of classes
@class CSDRSpectrumView;
@class CSDRWaterfallView;
@class CSDRDemod;
@class CSDRFFT;
@class CSDRAudioOutput;
@class CSDRRingBuffer;

#import <rtl-sdr/RTLSDRDevice.h>

@interface CSDRAppDelegate : NSObject <NSApplicationDelegate>
{
    // This is the dongle class (we also need to maintain a reference to the async block)
    RTLSDRDevice *device;
    RTLSDRAsyncBlock block;
    
    // This is the sample rate of the dongle
    // and the sample rate of the audio device
    int rfSampleRate;
    int afSampleRate;
    
    // These classes are the audio output device and the SDR algorithm
    CSDRAudioOutput *audioOutput;
    CSDRDemod *demodulator;
    NSString *_demodulationScheme;
    dispatch_queue_t demodQueue;
    
    // View helpers
    CSDRFFT *fftProcessor;
    NSTimer *viewTimer;
}

- (IBAction)showProperties:(id)sender;
- (IBAction)squelchChanged:(NSSlider *)sender;

@property (readwrite) IBOutlet NSSlider *ifBandwidthSlider;
@property (readwrite) IBOutlet NSSlider *afBandwidthSlider;
@property (readwrite) IBOutlet NSTextField *ifBandwidthField;
@property (readwrite) IBOutlet NSTextField *afBandwidthField;
- (IBAction)changeIFbandwidth:(NSSlider *)sender;
- (IBAction)changeAFbandwidth:(NSSlider *)sender;

@property (readwrite) IBOutlet NSLevelIndicator *bufferLevel;
@property (readwrite) IBOutlet NSLevelIndicator *powerLevel;
@property (readwrite) IBOutlet NSSlider *squelch;

@property (readwrite) IBOutlet NSWindow *window;
@property (readwrite) IBOutlet NSTextField *tuningField;
@property (readwrite) IBOutlet NSTextField *loField;
@property (readwrite) IBOutlet NSComboBox *demodulatorSelector;

@property (readwrite) IBOutlet CSDRSpectrumView  *spectrumView;
@property (readwrite) IBOutlet CSDRWaterfallView *waterfallView;
@property (readonly)  CSDRDemod *demodulator;
@property (readonly)  CSDRAudioOutput *audioOutput;

@property (readwrite) NSString *demodulationScheme;

@property (readwrite) float bottomValue;
@property (readwrite) float range;
@property (readwrite) float average;

@property (readwrite) float tuningValue;
@property (readwrite) float loValue;

@property (readonly)  NSData *fftData;

@end
