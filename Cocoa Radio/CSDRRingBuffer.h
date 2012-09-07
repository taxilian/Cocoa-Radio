//
//  CSDRRingBuffer.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/31/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreAudio/AudioHardware.h>
#import <AudioUnit/AudioUnit.h>

@interface CSDRRingBuffer : NSObject
{
    NSCondition *lock;
    
    NSMutableData *data;
    int tail, head;
}

@property (readonly) int fillLevel;

- (id)initWithCapacity:(NSInteger)cap;

- (void)storeData:(NSData *)data;
- (void)fetchFrames:(int)nFrames into:(AudioBufferList *)ioData;

@end
