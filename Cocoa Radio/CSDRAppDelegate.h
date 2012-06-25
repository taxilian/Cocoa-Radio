//
//  CSDRAppDelegate.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012). All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RTLSDRDevice;
@class CSDRSpectrumView;
@class CSDRWaterfallView;

#ifndef CSDRAPPDELEGATE_M
extern NSString *CocoaSDRRawDataNotification;
extern NSString *CocoaSDRFFTDataNotification;
extern NSString *CocoaSDRBaseBandNotification;
#endif

@interface CSDRAppDelegate : NSObject <NSApplicationDelegate>
{
    RTLSDRDevice *device;
    
    NSThread *readThread;

    float tuningValue;
    float loValue;
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


- (NSDictionary *)complexFFTOnDict:(NSDictionary *)inDict;

@end
