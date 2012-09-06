//
//  audioDevice.m
//  Cocoa Radio
//
//  Created by William Dillon on 5/27/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "audioDevice.h"
#import <CoreAudio/CoreAudio.h>
#import "CSDRAppDelegate.h"

#include <pthread.h>

NSString *audioSourceNameKey = @"audioSourceName";
NSString *audioSourceNominalSampleRateKey = @"audioSourceNominalSampleRate";
NSString *audioSourceAvailableSampleRatesKey = @"audioSourceAvailableSampleRates";
NSString *audioSourceInputChannelsKey = @"audioSourceInputChannels";
NSString *audioSourceOutputChannelsKey = @"audioSourceOutputChannels";
NSString *audioSourceDeviceIDKey = @"audioSourceDeviceID";
NSString *audioSourceDeviceUIDKey = @"audioSourceDeviceUID";

@implementation AudioDevice

@synthesize sampleRate;
@synthesize blockSize;
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
        [AudioDevice initDeviceDict];});

    return devices;
}

- (void)unprepare
{
    return;
}

- (bool)prepare
{
    return NO;
}

- (void)start
{
    return;
}

- (void)stop
{
    return;
}

@end

@implementation AudioSource

// The user is expected to free the buffer
void *dequeueBuffer(audioFIFO_t *fifo, size_t *size)
{
    void *retval = NULL;
    pthread_mutex_lock(&fifo->lock);
    
    if (fifo->used > 0) {
        // Keep a reference to the buffer
        retval = fifo->head->buffer;
        
        // If space for the size is provided, copy the information
        if (size != NULL) {
            *size = fifo->head->bufferSize;
        }
        
        // Update the status of the buffer
        void *nextHead = fifo->head->nextBuffer; // (1)
        fifo->head->nextBuffer = fifo->unused;   // (2)
        fifo->unused = fifo->head;               // (3)
        fifo->head = nextHead;                   // (4)
        

        // Update counts
        fifo->used--;
        fifo->available++;
    }

    pthread_mutex_unlock(&fifo->lock);
    
    return retval;
}

// The provided buffer must have a lifetime at least as long as
// the object is in the FIFO.
void enqueueBuffer(audioFIFO_t *fifo, void *data, size_t dataLength)
{
    pthread_mutex_lock(&fifo->lock);
    
    if (fifo->available == 0) {
        fifo->unused = (audioFIFO_buffer_t *)malloc(sizeof(audioFIFO_buffer_t));
        if (fifo->unused == NULL) {
            NSLog(@"Unable to allocate FIFO object.");
            exit(EXIT_FAILURE);
        }
        
        fifo->unused->nextBuffer = NULL;
        fifo->available++;
    }
    
    // Keep a reference to the buffer
    fifo->unused->buffer = data;
    fifo->unused->bufferSize = dataLength;
            
    // Update the status of the buffer
    void *nextUnused = fifo->unused->nextBuffer; // (1)
    fifo->unused->nextBuffer = fifo->head;       // (2)
    fifo->head = fifo->unused;                   // (4)
    fifo->unused = nextUnused;                   // (3)
    
    // Update counts
    fifo->available--;
    fifo->used++;
    
    pthread_mutex_unlock(&fifo->lock);
    
}

void initBuffer(audioFIFO_t *fifo)
{
    pthread_mutex_init(&fifo->lock, NULL);
    fifo->used = 0;
    fifo->available = 0;
    fifo->head = NULL;
    fifo->unused = NULL;
}

void flushBuffers(audioFIFO_t *fifo)
{
    void *buffer;
    do {
        buffer = dequeueBuffer(fifo, NULL);
    } while (buffer != NULL);
}

int countBuffers(audioFIFO_t *fifo)
{
    int count = -1;
    pthread_mutex_lock(&fifo->lock);

    count = fifo->used;
    
    pthread_mutex_unlock(&fifo->lock);
    
    return count;
}

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

@implementation AudioSink

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
        
        [self setSampleRate:48000];
        [self setBlockSize:4800];
        
//        bufferFIFO = [[NSMutableArray alloc] init];

        // Initialize the FIFO
        initBuffer(&fifo);
        
        bufferCondition = [[NSCondition alloc] init];
        
        playerStateData = [[NSMutableData alloc] initWithLength:sizeof(struct AQPlayerState)];

        // Keep a self-referential pointer in recorderState
        struct AQPlayerState *state = [playerStateData mutableBytes];
        state->context = self;
    }
    
    return self;
}

#pragma mark -
#pragma mark Audio Queue processing
- (void)fillBuffer:(AudioQueueBufferRef)aqBuffer
{
    if (aqBuffer == nil) {
        return;
    }
 
    // Try to get a buffer
    size_t bufferLength = 0;
    void *buffer = dequeueBuffer(&fifo, &bufferLength);

    aqBuffer->mPacketDescriptionCount = 0;

    // If the buffer is nil, we had a buffer underrun Fill it with '0's
    if (buffer == NULL) {
        NSLog(@"Audio buffer underrun.");
        int capacity = aqBuffer->mAudioDataBytesCapacity;
        aqBuffer->mAudioDataByteSize = capacity;
        bzero(aqBuffer->mAudioData, capacity);
    }

    // Otherwise, copy the data into the buffer
    else {
        aqBuffer->mAudioDataByteSize = (uint32)bufferLength;
//        memcpy(aqBuffer->mAudioData, buffer, bufferLength);

        float *floatBytes = aqBuffer->mAudioData;
        // Load a sample sine wave into the buffer
        float delta_phase = 100. / 48000.;
        for (int i = 0; i < bufferSize / sizeof(float); i++) {
            float phase = (delta_phase * i);
            phase = fmod(phase, 1.) * 2.;
            floatBytes[i] = sinf(phase * M_PI);
        }
        
//        free(buffer);
    }
}

static void HandleOutputBuffer(void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    struct AQPlayerState *pAqData = (struct AQPlayerState *) aqData;
    
    AudioSink *node = pAqData->context;

    if (node.running == NO) return;

    [node fillBuffer:inBuffer];
    
    OSStatus result = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    if (result != noErr) {
        NSLog(@"Unable to enqueue buffer!");
        [node stop];
        return;
    }
}

- (void)audioAvailable:(NSNotification *)notification
{
    [self bufferData:[notification object]];
}

#pragma mark -
#pragma mark Execution methods
- (bool)prepare
{
    if (prepared) {
        return YES;
    }
    
    // Select the device
    NSDictionary *deviceDict = [[AudioDevice deviceDict] objectAtIndex:self.deviceID];
    
    // Derive the hw sample rate
    hwSampleRate = 0;
    float swSampleRate = self.sampleRate;

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
    
    if (hwSampleRate == 0) {
        NSLog(@"Unable to set sample rate: %f.", swSampleRate);
        return NO;
    }
    
    // Get a reference to the state
    struct AQPlayerState *state = [playerStateData mutableBytes];
    int channels = 1;

    // Setup the desired parameters from the Audio Queue
    state->mDataFormat.mFormatID = kAudioFormatLinearPCM;
    state->mDataFormat.mSampleRate = hwSampleRate;
    state->mDataFormat.mChannelsPerFrame = channels;
    state->mDataFormat.mBitsPerChannel = 8 * sizeof(Float32);
    state->mDataFormat.mBytesPerPacket = channels * sizeof(Float32);
    state->mDataFormat.mBytesPerFrame  = channels * sizeof(Float32);
    state->mDataFormat.mFramesPerPacket = 1;
    state->mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat |
                                      kLinearPCMFormatFlagIsPacked;

    // Get the buffer size
    float bufferDuration = (float)self.blockSize / (float)self.sampleRate;
    bufferSize = [AudioSink bufferSizeWithQueue:state->mQueue
                                           Desc:state->mDataFormat
                                        Seconds:bufferDuration];
    
    // Create a block for the callback
    AudioQueueOutputCallbackBlock callback = ^(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
        HandleOutputBuffer(state, inAQ, inBuffer);};
    
    // Create the new Audio Queue
    dispatch_queue_t audioQueue = dispatch_queue_create("com.us.alternet.cocoaradio.audioQueue",
                                                        DISPATCH_QUEUE_SERIAL);
    OSStatus result = AudioQueueNewOutputWithDispatchQueue(&state->mQueue, &state->mDataFormat, 0,
                                                           audioQueue, callback);

    if (result != noErr) {
        NSLog(@"Unable to create new input audio queue.");
        return NO;
    }
    
    // Set the device for this audioQueue
    CFStringRef   deviceUID;
    deviceUID = (__bridge CFStringRef)[deviceDict objectForKey:audioSourceDeviceUIDKey];
    UInt32 propertySize = sizeof(CFStringRef);
    result = AudioQueueSetProperty(state->mQueue,
                                   kAudioQueueProperty_CurrentDevice, 
                                   &deviceUID, propertySize);
    
    if (result != noErr) {
        NSLog(@"Unable to set audio queue device to %@", deviceUID);
        return NO;
    }

    // Create a set of buffers
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef newBuffer;
        AudioQueueAllocateBuffer(state->mQueue, (UInt32)bufferSize, &newBuffer);
        state->mBuffers[i] = newBuffer;
        
//        NSLog(@"Created buffer %d at 0x%llx.", i, (uint64_t)state->mBuffers[i]->mAudioData);
    }

    prepared = YES;
    
    // Subscribe to Audio notifications
    NSNotificationCenter *center;
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(audioAvailable:)
                   name:CocoaSDRAudioDataNotification object:nil];
    
    return YES;
}

- (void)stop
{
    self.running = NO;

// Get a reference to the Audio Queue state
    struct AQPlayerState *state = [playerStateData mutableBytes];

// Stop the audio queue
    OSStatus result = AudioQueueStop(state->mQueue, YES);
    if (result != noErr) {
        NSLog(@"Unable to stop the audio queue!");
        self.running = YES;
    }

    return;
}

- (void)start
{
    OSStatus result = noErr;
    
// Make sure the node is prepared
    if (!prepared) {
        if ([self prepare] == NO) {
            return;
        }
    }
    
    self.running = YES;
    
// Get a reference to the Audio Queue state
    struct AQPlayerState *state = [playerStateData mutableBytes];

// Load existing buffers into audio queue for priming

    // If there aren't any, prime with one buffer of silence
    if (countBuffers(&fifo) == 0) {
        void *buffer = malloc(bufferSize);
        bzero(buffer, sizeof(float) * bufferSize);
        enqueueBuffer(&fifo, buffer, bufferSize);
    }
        
    int i;
    for (i = 0; i < kNumberBuffers && countBuffers(&fifo) > 0; i++) {
        HandleOutputBuffer(state, state->mQueue, state->mBuffers[i]);
    }
    
// Prime
    UInt32 numberPrepared = 0;
    result = AudioQueuePrime(state->mQueue, 0, &numberPrepared);
    if (result != noErr) {
        NSLog(@"Unable to prime the audio queue.");
        return;
    } else {
        NSLog(@"Primed with %d frames.", numberPrepared);
    }

// Start audio
    result = AudioQueueStart(state->mQueue, NULL);
    if (result != noErr) {
        NSLog(@"Unable to start the audio queue!");
        return;
    }

    return;
}

- (void)unprepare
{
    if (!prepared) {
        return;
    }

// Stop the queue NOW
    struct AQPlayerState *state = [playerStateData mutableBytes];
    AudioQueueStop(state->mQueue, YES);

// Discard audio
    flushBuffers(&fifo);
    
// Release buffers
    for (int i = 0; i < kNumberBuffers; ++i) { 
        AudioQueueFreeBuffer(state->mQueue, state->mBuffers[i]);
    }
    
    prepared = NO;
}

- (void)bufferData:(NSData *)data
{
    if (data == nil) {
        NSLog(@"Attempt to enqueue nil buffer.");
        return;
    }
    
    float *bytes = malloc(bufferSize);
    
    // Load a sample sine wave into the buffer
    float delta_phase = 100. / 48000.;
    for (int i = 0; i < bufferSize / sizeof(float); i++) {
        float phase = (delta_phase * i);
        phase = fmod(phase, 1.) * 2.;
        bytes[i] = sinf(phase * M_PI);
    }
    
    enqueueBuffer(&fifo, bytes, bufferSize);
    
}

@end