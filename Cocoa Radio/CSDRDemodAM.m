//
//  CSDRDemodAM.m
//  Cocoa Radio
//
//  Created by William Dillon on 10/15/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemodAM.h"
#import "dspRoutines.h"
#import "dspprobes.h"

@implementation CSDRDemodAM

- (id)initWithRFRate:(float)rfRate
              AFRate:(float)afRate
{
    self = [super initWithRFRate:rfRate AFRate:afRate];
    if (self != nil) {
        IFFilter.bandwidth  = 90000;
        IFFilter.skirtWidth = 20000;
        IFFilter.gain = 1.;
        
        // Stereo WBFM Radio has a pilot tone at 19KHz.  It's better to
        // filter this signal out.  Therefore, we'll set the maximum af
        // frequency to 18 KHz + a 1KHz skirt width.
        AFFilter.bandwidth  = 18000;
        AFFilter.skirtWidth = 10000;
        AFFilter.gain = .5;
        
        average = NAN;
        
        radioPower = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (id)init
{
    return [self initWithRFRate:2048000 AFRate:48000];
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    // Make sure that the temporary arrays are big enough
    int samples = [complexInput[@"real"] length] / sizeof(float);
    if ([radioPower length] < (samples * sizeof(float))) {
        [radioPower setLength:samples * sizeof(float)];
    }
    
    // Down convert
    NSDictionary *baseBand;
    baseBand = freqXlate(complexInput, self.centerFreq, self.rfSampleRate);
    
    // Low-pass filter
    NSDictionary *filtered;
    filtered = [IFFilter filterDict:baseBand];
    
    // Get an array of signal power levels
    getPower(filtered, radioPower, powerContext, .0001);
    
    // Make a copy of the power for AM
    NSMutableData *demodulated = [radioPower mutableCopy];
    
    // Remove residual DC likely contributed from modulation depth
    removeDC(demodulated, &average, .001);
    
    // Audio Frequency filter
    NSMutableData *audioFiltered;
    audioFiltered = (NSMutableData *)[AFFilter filterData:demodulated];
    
    // Iterate through the audio and mute sections that are too low
    // for now, just use a manual squelch threshold
    
    const float *powerSamples = [radioPower bytes];
    float *audioSamples = [audioFiltered mutableBytes];
    double newAverage = 0;
    
    for (int i = 0; i < samples; i++) {
        double powerSample = powerSamples[i];
        newAverage += powerSample / (double)samples;

//        bool mute = (powerSample > self.squelch)? NO : YES;
//        float audioSample = audioSamples[i];
//        audioSamples[i] = (mute)? 0. : (audioSample - 1.);
//        audioSamples[i] = audioSamples[i] / 30.;
    }

    // Copy average power into the rfPower variable
    COCOARADIO_DEMODAVERAGE((int)(rfPower * 1000));
    rfPower = newAverage * 10;
    
//    float duration = [complexInput[@"real"] length] / self.rfSampleRate;
//    return [[NSMutableData alloc] initWithLength:(self.afSampleRate * duration)];
    
    // Rational resampling
    NSData *audio;
    audio = [AFResampler resample:audioFiltered];
    
    return audio;
}

// Override the defaults as appropriate for WBFM
- (float)ifMaxBandwidth
{
    return  100000;
}

- (float)ifMinBandwidth
{
    return   15000;
}

// Stereo WBFM Radio has a pilot tone at 19KHz.  It's better to
// filter this signal out.  Therefore, we'll set the maximum af
// frequency to 18 KHz + a 1KHz skirt width.
- (float)afMaxBandwidth
{
    return 18000;
}

@end
