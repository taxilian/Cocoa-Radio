//
//  CSDRAppDelegate.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012). All rights reserved. Licensed under the GPL v.2
//

#import <Cocoa/Cocoa.h>

@class RTLSDRDevice;

@class CSDRSpectrumView;
@class CSDRWaterfallView;

@class CSDRDemod;

//@class AudioSink;
@class CSDRAudioOutput;

#import "NetworkServer.h"
#import "NetworkSession.h"

#ifndef CSDRAPPDELEGATE_M
extern NSString *CocoaSDRRawDataNotification;
extern NSString *CocoaSDRFFTDataNotification;
extern NSString *CocoaSDRBaseBandNotification;
extern NSString *CocoaSDRAudioDataNotification;
#endif

@interface CSDRAppDelegate : NSObject <NSApplicationDelegate>//, NetworkServerDelegate, NetworkSessionDelegate>
{
    // This is the dongle class
    RTLSDRDevice *device;
    
    // This thread is for the loop that reads from the dongle
    NSThread *readThread;

    // This is the sample rate of the dongle
    int rfSampleRate;

    // This is the sample rate of the audio device
    int afSampleRate;
    
    // These classes are the audio output device and the SDR algorithm
    CSDRAudioOutput *audioOutput;
    CSDRDemod *demodulator;
    
    // This is for network debugging (i.e. GNU Radio)
    NetworkServer *netServer;
    NSMutableArray *sessions;
    
    NSDictionary *fftBufferDict;

    // This is for file debugging (i.e. Audacity, or GNU Radio)
    NSMutableData *outData;
}

@property (readwrite) IBOutlet NSWindow *window;
@property (readwrite) IBOutlet NSTextField *tuningField;
@property (readwrite) IBOutlet NSTextField *loField;

@property (readwrite) IBOutlet CSDRSpectrumView  *spectrumView;
@property (readwrite) IBOutlet CSDRWaterfallView *waterfallView;

@property (readwrite) float bottomValue;
@property (readwrite) float range;
@property (readwrite) float average;

@property (readwrite) float tuningValue;
@property (readwrite) float loValue;

@property (readonly)  CSDRDemod *demodulator;


@end
