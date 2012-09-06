//
//  CSDRDemod.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "dspRoutines.h"

@implementation CSDRDemod

- (id)init
{
    self = [super init];
    if (self != nil) {

        // Setup the intermediate frequency filter
        IFFilter = [[CSDRlowPassComplex alloc] init];
        [IFFilter setGain:1.];
        
        // Setup the audio frequency filter
        AFFilter = [[CSDRlowPassFloat alloc] init];
        [AFFilter setGain:.5];
        
        // Setup the audio frequency rational resampler
        AFResampler = [[CSDRResampler alloc] init];
                
        // Set default sample rates (this will set decimation and interpolation)
        _rfSampleRate = 2048000;
        self.afSampleRate = 48000;

        self.ifBandwidth  = 90000;
        self.ifSkirtWidth = 20000;

        self.afBandwidth  = 24000;
        self.afSkirtWidth = 20000;
    }
    
    return self;
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    NSLog(@"Demodulating in the base class!");
    
    return nil;
}

#pragma mark Utility routines
int gcd(int a, int b) {
    if (a == 0) return b;
    if (b == 0) return a;
    
    if (a > b) return gcd(a - b, b);
    else       return gcd(a, b - a);
}

- (void)calculateResampleRatio
{
    // Get the GCD between sample rates (makes ints)
    int GCD = gcd(self.rfSampleRate, self.afSampleRate);
    
    int interpolator = self.afSampleRate / GCD;
    int decimator    = self.rfSampleRate / GCD;
    
    [AFResampler setInterpolator:interpolator];
    [AFResampler setDecimator:decimator];
}

#pragma mark Getters and Setters
- (void)setRfSampleRate:(float)rfSampleRate
{
    _rfSampleRate = rfSampleRate;
    
    [IFFilter setSampleRate:_rfSampleRate];
    [AFFilter setSampleRate:_rfSampleRate];
    
    [self calculateResampleRatio];
}

- (float)rfSampleRate
{
    return _rfSampleRate;
}

- (void)setAfSampleRate:(float)afSampleRate
{
    _afSampleRate = afSampleRate;
    
    [self calculateResampleRatio];
}

- (float)afSampleRate
{
    return _afSampleRate;
}

- (void)setIfBandwidth:(float)ifBandwidth
{
    [IFFilter setBandwidth:ifBandwidth];
}

- (float)ifBandwidth
{
    return [IFFilter skirtWidth];
}

- (void)setIfSkirtWidth:(float)ifSkirtWidth
{
    [IFFilter setSkirtWidth:ifSkirtWidth];
}

- (float)ifSkirtWidth
{
    return [IFFilter skirtWidth];
}

- (void)setAfBandwidth:(float)afBandwidth
{
    [AFFilter setBandwidth:afBandwidth];
}

- (float)afBandwidth
{
    return [AFFilter skirtWidth];
}

- (void)setAfSkirtWidth:(float)afSkirtWidth
{
    [AFFilter setSkirtWidth:afSkirtWidth];
}

- (float)afSkirtWidth
{
    return [AFFilter skirtWidth];
}

@end

#pragma mark -
@implementation CSDRDemodFM

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    // Down convert
    NSDictionary *baseBand;
    baseBand = freqXlate(complexInput, self.centerFreq, self.rfSampleRate);
    
    // Low-pass filter
    NSDictionary *filtered;
    filtered = [IFFilter filterDict:baseBand];

    // Quadrature demodulation
    NSData *demodulated;
    demodulated = quadratureDemod(filtered, 1., 0.);

    // Audio Frequency filter
    NSData *audioFiltered;
    audioFiltered = [AFFilter filterData:demodulated];

    // Rational resampling
    NSData *audio;
    audio = [AFResampler resample:audioFiltered];
        
    // Generate a test signal
//    static float lastPhase = 0.;
//    NSDictionary *signal = createComplexTone([audio length] / sizeof(float), 48000, 100, &lastPhase);
//    return signal[@"real"];
    
    return audio;
}

@end
