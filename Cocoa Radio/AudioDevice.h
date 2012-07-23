//
//  audioDevice.h
//  Cocoa Radio
//
//  Created by William Dillon on 5/27/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioQueue.h>

@interface audioDevice : NSObject
{
    bool done;
    
    bool prepared;
    
    int hwSampleRate;
}

@property (retain) NSString *sampleRate;
@property (retain) NSString *blockSize;
@property (retain) NSString *type;
@property (readwrite) bool done;
@property (readwrite) bool stereo;

+ (NSArray *)deviceDict;

@end

// This (audio input) hasn't been implemented yet.
// It isn't needed yet, as the rtl-sdr doesn't transmit.
@interface audioSource : audioDevice
{
}

+ (size_t)bufferSizeWithQueue:(AudioQueueRef)audioQueue
                         Desc:(AudioStreamBasicDescription)ASBDescription
                      Seconds:(Float64)seconds;

@end

@class audioSink;

static const int kNumberBuffers = 10;

struct AQPlayerState {
    AudioStreamBasicDescription    mDataFormat;
    AudioQueueRef                  mQueue;
    AudioQueueBufferRef            mBuffers[kNumberBuffers];
    SInt64                         mCurrentPacket;
    UInt32                         mNumPacketsToRead;
    AudioStreamPacketDescription  *mPacketDescs;
    audioSink                     *audioSink;
};

@interface audioSink : audioDevice
{
    DAGAudioSinkViewController *viewController;
    
    size_t bufferSize;
    NSMutableArray *bufferFIFO;
    NSCondition *bufferCondition;

    float swSampleRate;
    int blocksPerBuffer;
    float bufferDuration;
    
    struct AQPlayerState state;
}

@end
