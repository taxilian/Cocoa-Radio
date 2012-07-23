//
//  audioDevice.m
//  Cocoa Radio
//
//  Created by William Dillon on 5/27/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "audioDevice.h"
#import <CoreAudio/CoreAudio.h>

NSString *audioSourceNameKey = @"audioSourceName";
NSString *audioSourceNominalSampleRateKey = @"audioSourceNominalSampleRate";
NSString *audioSourceAvailableSampleRatesKey = @"audioSourceAvailableSampleRates";
NSString *audioSourceInputChannelsKey = @"audioSourceInputChannels";
NSString *audioSourceOutputChannelsKey = @"audioSourceOutputChannels";
NSString *audioSourceDeviceIDKey = @"audioSourceDeviceID";
NSString *audioSourceDeviceUIDKey = @"audioSourceDeviceUID";

@implementation audioDevice

@synthesize sampleRate;
@synthesize blockSize;
@synthesize type;
@synthesize done;
@synthesize stereo;

NSMutableArray *devices;

+ (void)initDeviceDict
{
    // Variables used for each of the functions
    UInt32 propertySize = 0;
    Boolean writable = NO;
    AudioObjectPropertyAddress property;
    
    // Get the size of the device IDs array
    property.mSelector = kAudioHardwarePropertyDevices;
    property.mScope    = kAudioObjectPropertyScopeGlobal;
    property.mElement  = kAudioObjectPropertyElementMaster;
    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                   &property, 0, NULL, &propertySize);
    
    // Create the array for device IDs
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(propertySize);
    
    // Get the device IDs
    AudioObjectGetPropertyData(kAudioObjectSystemObject, 
                               &property, 0, NULL, 
                               &propertySize, deviceIDs);
    
    NSUInteger numDevices = propertySize / sizeof(AudioDeviceID);
    
    // This is the array to hold the NSDictionaries
    devices = [[NSMutableArray alloc] initWithCapacity:numDevices];
    
    // Get per-device information
    for (int i = 0; i < numDevices; i++) {
        NSMutableDictionary *deviceDict = [[NSMutableDictionary alloc] init];
        [deviceDict setValue:[NSNumber numberWithInt:i]
                      forKey:audioSourceDeviceIDKey];
        
        CFStringRef string;
        
        // Get the name of the audio device
        property.mSelector = kAudioObjectPropertyName;
        property.mScope    = kAudioObjectPropertyScopeGlobal;
        property.mElement  = kAudioObjectPropertyElementMaster;
        
        propertySize = sizeof(string);
        AudioObjectGetPropertyData(deviceIDs[i], &property, 0, NULL, 
                                   &propertySize, &string);
        
        // Even though it's probably OK to use the CFString as an NSString
        // I'm going to make a copy, just to be safe.
        NSString *deviceName = [(__bridge NSString *)string copy];
        CFRelease(string);
        
        [deviceDict setValue:deviceName
                      forKey:audioSourceNameKey];
        
        // Get the UID of the device, used by the audioQueue
        property.mSelector = kAudioDevicePropertyDeviceUID;
        propertySize = sizeof(string);
        AudioObjectGetPropertyData(deviceIDs[i], &property, 0, NULL, 
                                   &propertySize, &string);
        
        // Again, copy to a NSString...
        NSString *deviceUID = [(__bridge NSString *)string copy];
        CFRelease(string);

        [deviceDict setValue:deviceUID
                      forKey:audioSourceDeviceUIDKey];
        
        // Get the nominal sample rate
        Float64 currentSampleRate = 0;
        propertySize = sizeof(currentSampleRate);
        AudioDeviceGetProperty(deviceIDs[i], 0, NO, 
                               kAudioDevicePropertyNominalSampleRate,
                               &propertySize, &currentSampleRate);
        
        
        [deviceDict setValue:[NSNumber numberWithFloat:currentSampleRate]
                      forKey:audioSourceNominalSampleRateKey];
        
        // Get an array of sample rates
        AudioValueRange *sampleRates;
        AudioDeviceGetPropertyInfo(deviceIDs[i], 0, NO, 
                                   kAudioDevicePropertyAvailableNominalSampleRates, 
                                   &propertySize, &writable);
        sampleRates = (AudioValueRange *)malloc(propertySize);
        AudioDeviceGetProperty(deviceIDs[i], 0, NO, 
                               kAudioDevicePropertyAvailableNominalSampleRates, 
                               &propertySize, sampleRates);
        
        NSUInteger numSampleRates = propertySize / sizeof(AudioValueRange);
        NSMutableArray *sampleRateTempArray = [[NSMutableArray alloc] init];
        for (int j = 0; j < numSampleRates; j++) {
            // An NSRange is a location and length...
            NSRange sampleRange;
            sampleRange.length   = sampleRates[j].mMaximum - sampleRates[j].mMinimum;
            sampleRange.location = sampleRates[j].mMinimum;
            
            [sampleRateTempArray addObject:[NSValue valueWithRange:sampleRange]];
        }
        
        // Create a immutable copy of the available sample rate array
        // and store it into the NSDict
        NSArray *tempArray = [sampleRateTempArray copy];

        [deviceDict setValue:tempArray
                      forKey:audioSourceAvailableSampleRatesKey];

        free(sampleRates);
        
        // Get the number of output channels for the device
        AudioBufferList bufferList;
        propertySize = sizeof(bufferList);
        AudioDeviceGetProperty(deviceIDs[i], 0, NO, 
                               kAudioDevicePropertyStreamConfiguration, 
                               &propertySize, &bufferList);
        
        int outChannels, inChannels;
        if (bufferList.mNumberBuffers > 0) {
            outChannels = bufferList.mBuffers[0].mNumberChannels;
            [deviceDict setValue:[NSNumber numberWithInt:outChannels]
                          forKey:audioSourceOutputChannelsKey];
        } else {
            [deviceDict setValue:[NSNumber numberWithInt:0]
                          forKey:audioSourceOutputChannelsKey];            
        }
        
        // Again for input channels
        propertySize = sizeof(bufferList);
        AudioDeviceGetProperty(deviceIDs[i], 0, YES, 
                               kAudioDevicePropertyStreamConfiguration, 
                               &propertySize, &bufferList);
        
        // The number of channels is the number of buffers.
        // The actual buffers are NULL.
        if (bufferList.mNumberBuffers > 0) {
            inChannels = bufferList.mBuffers[0].mNumberChannels;
            [deviceDict setValue:[NSNumber numberWithInt:inChannels]
                          forKey:audioSourceInputChannelsKey];
        } else {
            [deviceDict setValue:[NSNumber numberWithInt:0]
                          forKey:audioSourceInputChannelsKey];
        }
        
        // Add this new device dict to the array and release it
        [devices addObject:deviceDict];
    }
}

+(NSArray *)deviceDict
{
    static dispatch_once_t dictOnceToken;
    dispatch_once(&dictOnceToken, ^{
        [audioDevice initDeviceDict];});

    return devices;
}

@end

@implementation audioSource

+ (size_t)bufferSizeWithQueue:(AudioQueueRef)audioQueue
                         Desc:(AudioStreamBasicDescription)ASBDescription
                      Seconds:(Float64)seconds
{
    UInt32 outBufferSize = 0;
    static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize,
                              &maxPacketSize, &maxVBRPacketSize);
    }
    
    Float64 numBytesForTime = ASBDescription.mSampleRate * maxPacketSize * seconds;
    outBufferSize = (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);
    
    return outBufferSize;
}

@end

@implementation audioSink

+ (size_t)bufferSizeWithQueue:(AudioQueueRef)audioQueue
                         Desc:(AudioStreamBasicDescription)ASBDesc
                      Seconds:(Float64)seconds
{
    UInt32 outBufferSize = 0;
    static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = ASBDesc.mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize,
                              &maxPacketSize, &maxVBRPacketSize);
    }
    
    Float64 numBytesForTime = ASBDesc.mSampleRate * maxPacketSize * seconds;
    outBufferSize = (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);
    
    return outBufferSize;
}

#pragma mark -
#pragma mark Init and Dealloc
- (id)init {
    self = [super init];
    if (self) {
        prepared = NO;
        
        [self setType:@"float"];
        [self setSampleRate:@"48000"];
        [self setBlockSize:@"4800"];
        
        NSArray *devicesTemp = [audioDevice deviceDict];
        
        NSLog(@"Found %ld devices!", [devicesTemp count]);
    }
    
    return self;
}

#pragma mark -
#pragma mark Accessors, Setters, and Convenience
- (void)setBlockSize:(NSString *)blockSize
{
    [super setBlockSize:blockSize];
}

- (void)setStereo:(bool)stereo
{
    [super setStereo:stereo];
    
    NSString *typeString;
    if ([self stereo] == NSOnState) {
        typeString = [NSString stringWithFormat:@"%@2", [self type]];
    } else {
        typeString = [self type];
    }
}    

#pragma mark -
#pragma mark Audio Queue processing
- (void)fillBuffer:(AudioQueueBufferRef)aqBuffer
{
    if (aqBuffer == nil) {
        return;
    }
 
    aqBuffer->mPacketDescriptionCount = 0;
    aqBuffer->mAudioDataByteSize = bufferSize;

    NSData *inputData = nil;
    
    // Try to get a buffer
    [bufferCondition lock];
    if ([bufferFIFO count] != 0) {
        inputData = [bufferFIFO objectAtIndex:0];
        [bufferFIFO removeObjectAtIndex:0];
    }
    [bufferCondition unlock];
    [bufferCondition signal];
    
    // If the buffer is nil, we had a buffer underrun
    // Fill it with '0's
    if (inputData == nil) {
        NSLog(@"Audio buffer underrun.");
        bzero(aqBuffer->mAudioData, bufferSize);
    }

    else {
        // Otherwise, copy the data into the buffer
        const void *bytes = [inputData bytes];
        memcpy(aqBuffer->mAudioData,
               bytes, bufferSize);
    }
}

static void HandleOutputBuffer(void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    struct AQPlayerState *pAqData = (struct AQPlayerState *) aqData;
    
    audioSink *node = pAqData->audioSink;

    if ([node done]) return;

    [node fillBuffer:inBuffer];
    
    OSStatus result = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    if (result != noErr) {
        NSLog(@"Unable to enqueue buffer!");
        [node setDone:YES];
        return;
    }
}

- (NSData *)convertFormat:(NSData *)inData
{
    //    NSMutableData *outData = [[NSMutableData alloc] initWithLength:bufferSize];
    
    // Convert the format
    if ([[self type] caseInsensitiveCompare:@"float"] == NSOrderedSame) {
        return inData;
    }
    
    return nil;
    //    if ([[self type] caseInsensitiveCompare:@"int"] == NSOrderedSame) {
    //        
    //    }
}

#pragma mark -
#pragma mark Execution methods
- (bool)prepare
{
    if (prepared) {
        return YES;
    }
    
    if ([super prepare]) {
        // Audio buffering
        bufferFIFO = [[NSMutableArray alloc] init];
        bufferCondition = [[NSCondition alloc] init];
        
        swSampleRate = [[self sampleRate] floatValue];
        float secondsPerBlock = [[self blockSize] floatValue] / swSampleRate;
        
        // The ideal is for about .5 seconds per audio queue buffer
        // Choose a number of sw blocks that make up this number
        blocksPerBuffer = floorf(.5 / secondsPerBlock);
        bufferDuration = secondsPerBlock * blocksPerBuffer;
        
        NSDictionary *deviceDict = [viewController getSelectedDevice];
        
        // Derive the hw sample rate
        hwSampleRate = 0;
        swSampleRate = [[self sampleRate] floatValue];
        float hwSampleRateDecim  = 0;
        float hwSampleRateInterp = 0;
        NSArray *sampleRates = [deviceDict objectForKey:audioSourceAvailableSampleRatesKey];
        for (NSValue *rangeValue in sampleRates) {
            NSRange range = [rangeValue rangeValue];
            
            // Exact match?
            if (swSampleRate >= range.location &&
                swSampleRate <= range.location + range.length) {
                hwSampleRate = swSampleRate;
                break;
            }
            
            // Is this the closest decimation rate so far?
            float maxRate = range.location + range.length;
            if (maxRate < swSampleRate && maxRate > hwSampleRateDecim) {
                hwSampleRateDecim = maxRate;
            }
            
            // Is this the closest interpolation rate so far?
            float minRate = range.location;
            if (minRate > swSampleRate && minRate < hwSampleRateInterp) {
                hwSampleRateInterp = minRate;
            }
        }
        
        // If possible, it should be equal to the sw sample rate
        // If not, choose the next-higher rate and interpolate
        // Finally, choose the next-slower rate and decimate
        if (hwSampleRate == 0) {
            if (hwSampleRateInterp == 0) {
                hwSampleRate = hwSampleRateDecim;
            } else {
                hwSampleRate = hwSampleRateInterp;
            }
        }
        
        OSULogs(LOG_INFO, @"Chose %d as the hardware sample rate.", hwSampleRate);
        
        // Keep a self-referential pointer in recorderState
        state.audioSink = self;

        int channels = 1;
        // Setup the desired parameters from the Audio Queue
        state.mDataFormat.mFormatID = kAudioFormatLinearPCM;
        state.mDataFormat.mSampleRate = hwSampleRate;
        state.mDataFormat.mChannelsPerFrame = channels;
        state.mDataFormat.mBitsPerChannel = 8 * sizeof(Float32);
        state.mDataFormat.mBytesPerPacket = channels * sizeof(Float32);
        state.mDataFormat.mBytesPerFrame  = channels * sizeof(Float32);
        state.mDataFormat.mFramesPerPacket = 1;
        state.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked;    

        // Get the buffer size
        bufferSize = [audioSink bufferSizeWithQueue:state.mQueue
                                                      Desc:state.mDataFormat
                                                   Seconds:bufferDuration];
        
        // Create a block for the callback
        AudioQueueOutputCallbackBlock callback = ^(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
            HandleOutputBuffer(&state, inAQ, inBuffer);};
        
        // Create the new Audio Queue
        OSStatus result = AudioQueueNewOutputWithDispatchQueue(&state.mQueue, &state.mDataFormat, 0,
                                                               dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                                                               callback);

        if (result != noErr) {
            OSULogs(LOG_FAIL,@"Unable to create new input audio queue.");
            return NO;
        }
        
        // Set the device for this audioQueue
        CFStringRef   deviceUID;
        deviceUID = (CFStringRef)[deviceDict objectForKey:audioSourceDeviceUIDKey];
        UInt32 propertySize = sizeof(CFStringRef);
        result = AudioQueueSetProperty(state.mQueue, 
                                       kAudioQueueProperty_CurrentDevice, 
                                       &deviceUID, propertySize);
        
        if (result != noErr) {
            NSLog(@"Unable to set audio queue device to %@", deviceUID);
            return NO;
        }

        // Create a set of buffers
        for (int i = 0; i < kNumberBuffers; ++i) { 
            AudioQueueAllocateBuffer(state.mQueue, bufferSize, &state.mBuffers[i]);
        }

        prepared = YES;
        return YES;
    }
    
    return NO;
}

- (void)stop
{
    done = YES;

}

- (void)unprepare
{
    if (!prepared) {
        return;
    }
    
    [bufferFIFO release];
    [bufferCondition release];

    // Stop the queue NOW
    AudioQueueStop(state.mQueue, YES);
    
    // Release buffers
    for (int i = 0; i < kNumberBuffers; ++i) { 
        AudioQueueFreeBuffer(state.mQueue, state.mBuffers[i]);
    }
    
    [super unprepare];
    
    prepared = NO;
}

- (void)run
{
    DAGArgument *arg = [arguments objectAtIndex:0];
    
    // Make sure the node is prepared
    if (!prepared) {
        if ([self prepare] == NO) {
            return;
        }
    }
    
    // Begin reading from the argument to prime the buffers
    // read the numBuffers amount of buffers
    NSMutableArray *audioBuffers = [[NSMutableArray alloc] init];
    for (int i = 0; i < kNumberBuffers; i++) {
        @autoreleasepool {
            NSMutableData *outData = [[NSMutableData alloc] init];

            for (int j = 0; j < blocksPerBuffer; j++) {
                // Get the data
                NSData *tempData = [arg getData];
                if (tempData == nil) {
                    [outData release];
                    [audioBuffers release];
                    done = YES;
                    return;
                }
                
                // Add the data to the buffer (10x)
                [outData appendData:tempData];
            }

            // Convert the format and store it
            [bufferFIFO addObject:[self convertFormat:outData]];
            HandleOutputBuffer(&state, state.mQueue, state.mBuffers[i]);
            [outData release];
        }
    }
    
    UInt32 numberPrepared = 0;
    UInt32 framesToPrime = (bufferSize / state.mDataFormat.mBytesPerFrame) * kNumberBuffers;
    OSStatus result = AudioQueuePrime(state.mQueue, framesToPrime, &numberPrepared);
    if (result != noErr) {
        OSULogs(LOG_FAIL, @"Unable to prime the audio queue.");
        return;
    } else {
        OSULogs(LOG_INFO, @"Primed with %d frames.", numberPrepared);
    }

    [audioBuffers release];

    // Pre-fill the buffers with 10 units
    for (int i = 0; i < 10; i++) {
        @autoreleasepool {
            NSMutableData *outData = [[NSMutableData alloc] init];
            
            for (int j = 0; j < blocksPerBuffer; j++) {
                // Get the data
                NSData *tempData = [arg getData];
                if (tempData == nil) {
                    [outData release];
                    done = YES;
                    return;
                }
                
                // Add the data to the buffer (10x)
                [outData appendData:tempData];
            }
            
            // Convert the format and store it
            [bufferFIFO addObject:[self convertFormat:outData]];
            [outData release];
        }
    }
    
    // Start audio
    result = AudioQueueStart(state.mQueue, NULL);
    if (result != noErr) {
        OSULogs(LOG_FAIL, @"Unable to start the audio queue!");
        return;
    }
    
    // Loop
    done = NO;
    NSMutableData *outData = [[NSMutableData alloc] initWithLength:bufferSize];
    char *bytes = [outData mutableBytes];
    do {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        for (int j = 0; j < blocksPerBuffer; j++) {
            // Get the data
            NSData *argData = [arg getData];
            if (argData == nil) {
                [outData release];
                done = YES;
                return;
            }

            int start = [argData length] * j;
            memcpy(&bytes[start], [argData bytes], [argData length]);
        }

        // Put in the buffer FIFO
        [bufferCondition lock];
        NSData *tempData = [outData copy];
        
        // Make sure the buffer isn't too full
        if ([bufferFIFO count] > 100) {
            [bufferCondition wait];
        }
        
        // The buffer has space
        [bufferFIFO addObject:[self convertFormat:tempData]];
        if (DAGNODE_AUDIO_BUFFER_FILL_ENABLED()) {
            DAGNODE_AUDIO_BUFFER_FILL([bufferFIFO count]);}

        [tempData release];
        [bufferCondition unlock];

        [pool drain];
    } while (!done);
    [outData release];
}

@end