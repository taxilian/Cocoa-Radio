//
//  CSDRAppDelegate.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012). All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RTLSDRDevice;

#ifndef CSDRAPPDELEGATE_M
extern NSString *CocoaSDRRawDataNotification;
extern NSString *CocoaSDRFFTDataNotification;
#endif

@interface CSDRAppDelegate : NSObject <NSApplicationDelegate>
{
    RTLSDRDevice *device;
    
    NSThread *readThread;

    float tuningValue;
}

@property (readwrite) IBOutlet NSWindow *window;
@property (readwrite) IBOutlet NSTextField *tuningField;

@property (readwrite) float bottomValue;
@property (readwrite) float range;


- (NSDictionary *)complexFFTOnDict:(NSDictionary *)inDict;

@end
