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
    
    AudioUnit unit;

    AudioComponent comp;
    AudioComponentDescription desc;
    AudioComponentInstance auHAL;
    
    size_t bufferSize;
    
    CSDRRingBuffer *ringBuffer;

}

+ (NSArray *)deviceDict;

- (bool)prepare;
- (void)unprepare;

- (bool)start;
- (void)stop;

@property (readwrite) int sampleRate;
@property (readwrite) int blockSize;
@property (readonly) bool running;
@property (readwrite) int deviceID;

@end

@interface CSDRAudioOutput : CSDRAudioDevice

- (void)bufferData:(NSData *)data;

@end