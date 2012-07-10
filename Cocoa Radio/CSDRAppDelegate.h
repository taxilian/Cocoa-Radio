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

@class CSDRlowPassFloat;
@class CSDRlowPassComplex;

#import "NetworkServer.h"
#import "NetworkSession.h"

#ifndef CSDRAPPDELEGATE_M
extern NSString *CocoaSDRRawDataNotification;
extern NSString *CocoaSDRFFTDataNotification;
extern NSString *CocoaSDRBaseBandNotification;
#endif

@interface CSDRAppDelegate : NSObject <NSApplicationDelegate, NetworkServerDelegate, NetworkSessionDelegate>
{
    RTLSDRDevice *device;
    
    NSThread *readThread;

    float tuningValue;
    float loValue;
    
    float _IFbandwidth;
    float _AFbandwidth;
    
    CSDRlowPassComplex *IFFilter;
    CSDRlowPassFloat *AFFilter;
    
    NetworkServer *netServer;
    NSMutableArray *sessions;
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

@property (readwrite) float IFbandwidth;
@property (readwrite) float AFbandwidth;

- (NSDictionary *)complexFFTOnDict:(NSDictionary *)inDict;

@end
