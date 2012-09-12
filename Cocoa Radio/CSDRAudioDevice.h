//
//  CSDRAudioDevice.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/30/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreAudio/AudioHardware.h>
#import <AudioUnit/AudioUnit.h>

@class CSDRRingBuffer;

@interface CSDRAudioDevice : NSObject
{
    bool _running;
    bool _prepared;
    
    bool discontinuity;
    
    AudioUnit unit;

    AudioComponent comp;
    AudioComponentDescription desc;
    AudioComponentInstance auHAL;
    
//    size_t bufferSize;
    
    CSDRRingBuffer *ringBuffer;

}

+ (NSArray *)deviceDict;

- (CSDRRingBuffer *)ringBuffer;

- (bool)prepare;
- (void)unprepare;

- (bool)start;
- (void)stop;

// This is used to mark a discontinuity, such as frequency change
// It's purpose is to discard packets in the buffer before the
// frequency change, then, when the buffer re-fills to 1/2 full,
// playing will resume.
- (void)markDiscontinuity;
- (bool)discontinuity;

@property (readwrite) int sampleRate;
@property (readwrite) int blockSize;
@property (readonly) bool running;
@property (readwrite) int deviceID;
@property (readwrite) bool mute;

@end

@interface CSDRAudioOutput : CSDRAudioDevice

- (void)bufferData:(NSData *)data;

@end