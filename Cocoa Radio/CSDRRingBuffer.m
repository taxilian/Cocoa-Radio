//
//  CSDRRingBuffer.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/31/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRRingBuffer.h"
#include "audioprobes.h"

@implementation CSDRRingBuffer

- (id)init
{
    return [self initWithCapacity:1024 * 1024];
}

- (id)initWithCapacity:(NSInteger)cap
{
    self = [super init];
    if (self != nil) {
        lock = [[NSCondition alloc] init];
        
        data = [[NSMutableData alloc] initWithLength:cap * sizeof(float)];
        tail = head = 0;
        
        NSLog(@"Created a ring buffer with %ld elements.", cap);
    }
    
    return self;
}

- (int)fillLevel
{
    int capacityFrames = [data length] / sizeof(float);
    return (head - tail + capacityFrames) % capacityFrames;
}

- (int)capacity
{
    return [data length] / sizeof(float);
}

- (void)clear
{
    head = tail = 0;
}

- (void)storeData:(NSData *)newData
{
    [lock lock];

    // Determine whether we'll overflow the buffer.
    int capacityFrames = [data length] / sizeof(float);
    int newDataFrames  = [newData length] / sizeof(float);

    int usedBuffer = head - tail;
    if (usedBuffer < 0) usedBuffer += capacityFrames;

    // DTrace it
    if (COCOARADIOAUDIO_RINGBUFFERFILL_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFERFILL(newDataFrames, head, tail);
    }

    int overflowAmount = newDataFrames - (capacityFrames - usedBuffer);
    if (overflowAmount > 0) {
//        NSLog(@"Ring buffer overflow");
    }
    
    // Do it the easy way
    float *outFloats = [data mutableBytes];
    const float *inFloats = [newData bytes];
    for (int i = 0; i < newDataFrames; i++) {
        outFloats[head] = inFloats[i];
        head = (head + 1) % capacityFrames;
        // Detect overflow
        if (head == tail) {
            tail = (head + 1) % capacityFrames;
        }
    }
    
    [lock unlock];
    return;
    
//    int overflowAmount = newDataFrames - (capacityFrames - usedBuffer);
//    if (overflowAmount > 0) {
//        NSLog(@"Audio ring buffer overflow");
//        // Adjust the head index
//        tail = (tail + overflowAmount) % capacityFrames;
//    }

    // Copy as much as possible from the tail to the buffer end
    int framesToEndOfBuffer = (capacityFrames - head);

    
// Do the write anyway
    memcpy(&outFloats[head], inFloats,
           framesToEndOfBuffer * sizeof(float));
    
    // Copy the remainder to the beginning of the buffer
    int remainder = newDataFrames - framesToEndOfBuffer;
    if (remainder > 0) {
        NSLog(@"write wrap");
        memcpy(outFloats, &inFloats[newDataFrames - remainder],
               remainder * sizeof(float));
    }
    
    // Adjust the head index
    head = (head + newDataFrames) % capacityFrames;
    
    // Make sure head != tail (that's the empty condition)
    if (tail == head) {
        tail = (tail + 1) % capacityFrames;
        NSLog(@"Audio ring buffer overflow (one byte)");
    }
        
    [lock unlock];
}

- (void)fetchFrames:(int)nFrames into:(AudioBufferList *)ioData
{
    // Basic sanity checking
    if (ioData->mBuffers[0].mDataByteSize < nFrames * sizeof(float)) {
        NSLog(@"Not enough memory provided for requested frames.");
        return;
    }
    
    [lock lock];

    // If we're dealing with a buffer underrun zero-out all the missing
    // data and make it fit within the buffer.
    int capacityFrames = [data length] / sizeof(float);
    int filledFrames = (head - tail + capacityFrames) % capacityFrames;

    if (filledFrames < nFrames) {
        NSLog(@"Buffer underflow");
    }
    
    // DTrace it
    if (COCOARADIOAUDIO_RINGBUFFEREMPTY_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFEREMPTY(nFrames, head, tail);
    }
    
    // Try doing this the lame (read: easy) way
    float *outFloats = ioData->mBuffers[0].mData;
    float *bufferFloats = [data mutableBytes];
    for (int i = 0; i < nFrames ; i++) {
        // Read the value from the tail into the buffer
        if (tail == head) {
            outFloats[i] = 0;
            tail--;
        } else {
            outFloats[i] = bufferFloats[tail];
        }
        tail = (tail + 1) % capacityFrames;
    }
    
    [lock unlock];
    return;
    
    int underrunFrames = nFrames - filledFrames;
    if (underrunFrames > 0) {
        NSLog(@"Buffer underrun!");
        nFrames -= underrunFrames;
    }
    
    // Was this a 0-byte read or a complete underrun?
    if (nFrames == 0) {
        [lock unlock];
        return;
    }
        
    // Now, we know that nFrames worth of data can be provided.

    // If the head has a greater index than the tail then the whole
    // buffer is linear in memory.  Therefore, the frames to the end
    // are simply head minus tail.
    int framesToEndOfBuffer = head - tail;

    // If the tail is greater, then it wraps around in memory.  We
    // can only read until the end of the ring buffer, then start
    // again at the beginning
    if (framesToEndOfBuffer < 0) {
        framesToEndOfBuffer = capacityFrames - tail;
    }

    // Even if there's lots of data to the end of the buffer, we only
    // want to read the number of requested frames (in indicies)
    int toRead = MIN(framesToEndOfBuffer, nFrames);

    // Perform the read
    // this is to sanitize the buffer in case of underrun
    bzero(outFloats, nFrames * sizeof(float));
    memcpy(outFloats, &bufferFloats[tail], toRead * sizeof(float));
    
    // If we didn't complete the read because we wrapped around,
    // continue at the beginning
    int remainder = nFrames - toRead;

    if (remainder > 0) {
        memcpy(&outFloats[toRead], bufferFloats, remainder * sizeof(float));
    }
    
    // Update the tail index
    tail = (tail + nFrames) % capacityFrames;
    
    [lock unlock];
}

// For now, a dumb copy.  Should call another function in the future
- (void)fillData:(NSMutableData *)inputData
{
    // Basic sanity checking
    int nFrames = [inputData length] / sizeof(float);
    
    [lock lock];
    
    // If we're dealing with a buffer underrun zero-out all the missing
    // data and make it fit within the buffer.
    int capacityFrames = [data length] / sizeof(float);
    int filledFrames = (head - tail + capacityFrames) % capacityFrames;
    
    if (filledFrames < nFrames) {
        NSLog(@"Buffer underflow");
    }
    
    // DTrace it
    if (COCOARADIOAUDIO_RINGBUFFEREMPTY_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFEREMPTY(nFrames, head, tail);
    }
    
    // Try doing this the lame (read: easy) way
    float *outFloats = [inputData mutableBytes];
    float *bufferFloats = [data mutableBytes];
    for (int i = 0; i < nFrames ; i++) {
        // Read the value from the tail into the buffer
        if (tail == head) {
            outFloats[i] = 0;
            tail--;
        } else {
            outFloats[i] = bufferFloats[tail];
        }
        tail = (tail + 1) % capacityFrames;
    }
    
    [lock unlock];
    return;
    
    int underrunFrames = nFrames - filledFrames;
    if (underrunFrames > 0) {
        NSLog(@"Buffer underrun!");
        nFrames -= underrunFrames;
    }
    
    // Was this a 0-byte read or a complete underrun?
    if (nFrames == 0) {
        [lock unlock];
        return;
    }
    
    // Now, we know that nFrames worth of data can be provided.
    
    // If the head has a greater index than the tail then the whole
    // buffer is linear in memory.  Therefore, the frames to the end
    // are simply head minus tail.
    int framesToEndOfBuffer = head - tail;
    
    // If the tail is greater, then it wraps around in memory.  We
    // can only read until the end of the ring buffer, then start
    // again at the beginning
    if (framesToEndOfBuffer < 0) {
        framesToEndOfBuffer = capacityFrames - tail;
    }
    
    // Even if there's lots of data to the end of the buffer, we only
    // want to read the number of requested frames (in indicies)
    int toRead = MIN(framesToEndOfBuffer, nFrames);
    
    // Perform the read
    // this is to sanitize the buffer in case of underrun
    bzero(outFloats, nFrames * sizeof(float));
    memcpy(outFloats, &bufferFloats[tail], toRead * sizeof(float));
    
    // If we didn't complete the read because we wrapped around,
    // continue at the beginning
    int remainder = nFrames - toRead;
    
    if (remainder > 0) {
        memcpy(&outFloats[toRead], bufferFloats, remainder * sizeof(float));
    }
    
    // Update the tail index
    tail = (tail + nFrames) % capacityFrames;
    
    [lock unlock];

}

@end
