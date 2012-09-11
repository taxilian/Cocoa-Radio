//
//  CSDRAudioDevice.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/30/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRAudioDevice.h"
#import "CSDRRingBuffer.h"
#import "CSDRAppDelegate.h"

#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioUnitUtilities.h>

#include "audioprobes.h"

#import <mach/mach_time.h>

double subtractTimes(uint64_t end, uint64_t start);

@implementation CSDRAudioDevice

NSString *audioSourceNameKey = @"audioSourceName";
NSString *audioSourceNominalSampleRateKey = @"audioSourceNominalSampleRate";
NSString *audioSourceAvailableSampleRatesKey = @"audioSourceAvailableSampleRates";
NSString *audioSourceInputChannelsKey = @"audioSourceInputChannels";
NSString *audioSourceOutputChannelsKey = @"audioSourceOutputChannels";
NSString *audioSourceDeviceIDKey = @"audioSourceDeviceID";
NSString *audioSourceDeviceUIDKey = @"audioSourceDeviceUID";

@synthesize sampleRate;
@synthesize blockSize;

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
        [CSDRAudioDevice initDeviceDict];});
    
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

- (bool)start
{
    return NO;
}

- (void)stop
{
    return;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        // This code is generic for input and output
        // subclasses refine it further
        
        // !! this code is from Apple Technical Note TN2091
        //There are several different types of Audio Units.
        //Some audio units serve as Outputs, Mixers, or DSP
        //units. See AUComponent.h for listing
        desc.componentType = kAudioUnitType_Output;
        
        //Every Component has a subType, which will give a clearer picture
        //of what this components function will be.
        desc.componentSubType = kAudioUnitSubType_HALOutput;
        
        //all Audio Units in AUComponent.h must use
        //"kAudioUnitManufacturer_Apple" as the Manufacturer
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        
        //Finds a component that meets the desc spec's
        comp = AudioComponentFindNext(NULL, &desc);
        if (comp == NULL) return nil;
        
        //gains access to the services provided by the component
        AudioComponentInstanceNew(comp, &auHAL);
        
        // Subscribe to Audio notifications
        NSNotificationCenter *center;
        center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(audioAvailable:)
                       name:CocoaSDRAudioDataNotification object:nil];
    }
    
    return self;
}

- (bool)running
{
    return _running;
}



@end

@implementation CSDRAudioOutput

AudioBufferList *theBufferList;

OSStatus AudioUnitRender (AudioUnit                   inUnit,
                          AudioUnitRenderActionFlags  *ioActionFlags,
                          const AudioTimeStamp        *inTimeStamp,
                          UInt32                      inOutputBusNumber,
                          UInt32                      inNumberFrames,
                          AudioBufferList             *ioData)
{
    
    
    return noErr;
}

OSStatus OutputProc(void *inRefCon,
                    AudioUnitRenderActionFlags *ioActionFlags,
                    const AudioTimeStamp *TimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                    AudioBufferList * ioData)
{
    @autoreleasepool {
        CSDRAudioDevice *device = (__bridge CSDRAudioDevice *)inRefCon;
        CSDRRingBuffer *ringBuffer = [device ringBuffer];
        
        // During a period of discontinuity, produce silence
        if (device.discontinuity) {
            bzero(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
            bzero(ioData->mBuffers[1].mData, ioData->mBuffers[1].mDataByteSize);
            return noErr;
        }
        
        // Load some data out of the ring buffer
        [ringBuffer fetchFrames:inNumberFrames
                           into:ioData];
        
        // Copy the left channel to the right one
        memcpy(ioData->mBuffers[1].mData,
               ioData->mBuffers[0].mData,
               ioData->mBuffers[1].mDataByteSize);
        
        
        static uint64_t last_buffer_time = 0;
        static int lastFillLevel = 0;
        
        // Attempt to determine whether the buffer backlog is increasing
        if (COCOARADIOAUDIO_AUDIOBUFFER_ENABLED()) {
            uint64_t this_time = TimeStamp->mHostTime;
            double deltaTime = subtractTimes(this_time, last_buffer_time);
            
            double derivedSampleRate = inNumberFrames / deltaTime;
            
            int deltaTime_us;
            if (last_buffer_time == 0) {
                deltaTime_us = 0;
            } else {
                deltaTime_us = deltaTime * 1000000;
            }
            
            last_buffer_time = this_time;
            
            int fillLevel = [ringBuffer fillLevel];
            //        int deltaFillLevel = [ringBuffer fillLevel] - lastFillLevel;
            lastFillLevel = fillLevel;
            
            COCOARADIOAUDIO_AUDIOBUFFER((int)derivedSampleRate, fillLevel);
        }
        
        return noErr;
    }
}

+ (size_t)bufferSizeWithDesc:(AudioStreamBasicDescription)ASBDesc
                     Seconds:(Float64)seconds
{
    UInt32 outBufferSize = 0;
    static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = ASBDesc.mBytesPerPacket;
    Float64 numBytesForTime = ASBDesc.mSampleRate * maxPacketSize * seconds;
    outBufferSize = (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);
    
    return outBufferSize;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        
        // !! this code is from Apple Technical Note TN2091
        // This code disables the "input bus" of the HAL
        UInt32 enableIO;
        
        UInt32 size;
        OSStatus err =noErr;
        size = sizeof(AudioDeviceID);
        
        // Select the default device
        AudioDeviceID outputDevice;
        err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice,
                                       &size,
                                       &outputDevice);
        
        if (err) return nil;
        
        err = AudioUnitSetProperty(auHAL,
                                   kAudioOutputUnitProperty_CurrentDevice,
                                   kAudioUnitScope_Global,
                                   0,
                                   &outputDevice,
                                   sizeof(outputDevice));

        //When using AudioUnitSetProperty the 4th parameter in the method
        //refer to an AudioUnitElement. When using an AudioOutputUnit
        //the input element will be '1' and the output element will be '0'.
        
        enableIO = 0;
        AudioUnitSetProperty(auHAL,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             1, // input element
                             &enableIO,
                             sizeof(enableIO));
        
        enableIO = 1;
        AudioUnitSetProperty(auHAL,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output,
                             0,   //output element
                             &enableIO,
                             sizeof(enableIO));
        
    }
    
    return self;
}

- (bool)prepare
{
    if (_prepared == YES) {
        return YES;
    }
    
// Setup the device characteristics
    AudioStreamBasicDescription deviceFormat;
    AudioStreamBasicDescription desiredFormat;
    
    int channels = 1;
    desiredFormat.mFormatID = kAudioFormatLinearPCM;
    desiredFormat.mSampleRate = self.sampleRate;
    desiredFormat.mChannelsPerFrame = channels;
    desiredFormat.mBitsPerChannel  = 8 * sizeof(float);
    desiredFormat.mBytesPerFrame   = sizeof(float) * channels;
    desiredFormat.mBytesPerPacket  = sizeof(float) * channels;
    desiredFormat.mFramesPerPacket = 1;
    desiredFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat |
                                 kLinearPCMFormatFlagIsPacked;
    
    //set format to output scope
    AudioUnitSetProperty(auHAL,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         1,
                         &desiredFormat,
                         sizeof(AudioStreamBasicDescription));

    UInt32 size = sizeof(AudioStreamBasicDescription);
    
    OSStatus err =noErr;
    Float64 trySampleRate = self.sampleRate;
    err = AudioUnitSetProperty(auHAL,
                               kAudioUnitProperty_SampleRate,
                               kAudioUnitScope_Global,
                               0,
                               &trySampleRate,
                               sizeof(trySampleRate));

    trySampleRate = 0.;
    err = AudioUnitGetProperty(auHAL,
                               kAudioUnitProperty_SampleRate,
                               kAudioUnitScope_Global,
                               0,
                               &trySampleRate,
                               &size);
    
    //Get the input device format
    AudioUnitGetProperty (auHAL,
                          kAudioUnitProperty_StreamFormat,
                          kAudioUnitScope_Output,
                          1,
                          &deviceFormat,
                          &size);
    
// Get the buffer size
    float bufferDuration = (float)self.blockSize / (float)self.sampleRate;
    bufferSize = [CSDRAudioOutput bufferSizeWithDesc:deviceFormat
                                             Seconds:bufferDuration];

    // Calculate a seconds worth of data
//    int ringbufferSize = self.sampleRate * sizeof(float);
    ringBuffer = [[CSDRRingBuffer alloc] initWithCapacity:self.sampleRate];
//    ringBuffer = [[CSDRRingBuffer alloc] initWithCapacity:19200];
//    buffer = new_ringbuffer(ringbufferSize);
    
// allocate the AudioBufferList and two AudioBuffers:
    theBufferList = (AudioBufferList *)malloc(offsetof(AudioBufferList, mBuffers[2]));
    theBufferList->mNumberBuffers = 2;
    theBufferList->mBuffers[0].mNumberChannels = 1;
    theBufferList->mBuffers[0].mData =  malloc(bufferSize);
    theBufferList->mBuffers[0].mDataByteSize = (UInt32)bufferSize;
    theBufferList->mBuffers[1].mNumberChannels = 1;
    theBufferList->mBuffers[1].mData =  malloc(bufferSize);
    theBufferList->mBuffers[1].mDataByteSize = (UInt32)bufferSize;

// Setup the callback
    AURenderCallbackStruct output;
    output.inputProc = OutputProc;
    output.inputProcRefCon = (__bridge void *)(self);
    	
	AudioUnitSetProperty(auHAL,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         0,
                         &output,
                         sizeof(output));
    
    _prepared = YES;
    return YES;
}

- (bool)start
{
    if (!_prepared) {
        if (![self prepare]) return NO;
    }
    
    OSStatus err = noErr;
    err = AudioUnitInitialize(auHAL);
    if(err)
        return NO;

    err = AudioOutputUnitStart(auHAL);
    if(err)
        return NO;

    _running = YES;
    discontinuity = NO;
    
    AudioStreamBasicDescription deviceFormat;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty (auHAL,
                          kAudioUnitProperty_StreamFormat,
                          kAudioUnitScope_Output,
                          1,
                          &deviceFormat,
                          &size);

    
    return YES;
}

-(bool)discontinuity
{
    return discontinuity;
}

- (void)markDiscontinuity
{
    discontinuity = YES;
    [ringBuffer clear];
}

- (CSDRRingBuffer *)ringBuffer
{
    return ringBuffer;
}

-(void)bufferData:(NSData *)data
{
    [ringBuffer storeData:data];

    // If it's not started yet, wait until the ringbuffer is half
    // full, then start it.
    if (!self.running) {
        if ([ringBuffer fillLevel] >= ([ringBuffer capacity] / 2)) {
            [self start];
        }
    } else if (discontinuity) {
        if ([ringBuffer fillLevel] >= ([ringBuffer capacity] / 2)) {
            discontinuity = false;
        }
    }
    
    return;
    
}

- (void)audioAvailable:(NSNotification *)notification
{
    [self bufferData:[notification object]];
}

@end
