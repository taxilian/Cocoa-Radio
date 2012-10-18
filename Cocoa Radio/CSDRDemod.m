//
//  CSDRDemod.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "dspRoutines.h"
#import "dspprobes.h"
#import "CSDRDemodAM.h"
#import "CSDRDemodWBFM.h"
#import "CSDRDemodNBFM.h"

@implementation CSDRDemod

- (id)initWithRFRate:(float)rfRate
              AFRate:(float)afRate
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
        _rfSampleRate = rfRate;
        _rfCorrectedRate = rfRate;
        IFFilter.sampleRate = rfRate;
        
        self.afSampleRate = afRate;
        AFFilter.sampleRate = afRate;
        
        // Assume nyquist for the AFFilter
        AFFilter.bandwidth  = self.afSampleRate / 2.;
        AFFilter.skirtWidth = 10000;
        
        self.squelch = 0.;
        radioPower = [[NSMutableData alloc] init];
    }
    
    return self;
}

// Just do the above initialization with some defaults
- (id)init
{
    return [self initWithRFRate:2048000 AFRate:48000];
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    NSLog(@"Demodulating in the base class!");
    
    return nil;
}

+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme
{
    if ([scheme caseInsensitiveCompare:@"WBFM"] == NSOrderedSame) {
        return [[CSDRDemodWBFM alloc] init];
    }

    if ([scheme caseInsensitiveCompare:@"NBFM"] == NSOrderedSame) {
        return [[CSDRDemodNBFM alloc] init];
    }
    
    if ([scheme caseInsensitiveCompare:@"AM"] == NSOrderedSame) {
        return [[CSDRDemodAM alloc] init];
    }
    
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
    int GCD = gcd(self.rfCorrectedRate, self.afSampleRate);
    
    int interpolator = self.afSampleRate / GCD;
    int decimator    = self.rfCorrectedRate / GCD;
    
    [AFResampler setInterpolator:interpolator];
    [AFResampler setDecimator:decimator];

    if (decimator == 0) {
        NSLog(@"Setting decimator to 0!");
    }
    
//    NSLog(@"Set resample ratio to %d/%d", interpolator, decimator);
}

#pragma mark Getters and Setters
- (void)setRfSampleRate:(float)rfSampleRate
{
    _rfSampleRate = rfSampleRate;
    // Assume corrected rate equals requested until known better
    _rfCorrectedRate = rfSampleRate;
    
    [IFFilter setSampleRate:_rfSampleRate];
    [AFFilter setSampleRate:_rfSampleRate];
    
    [self calculateResampleRatio];
}

- (float)rfSampleRate
{
    return _rfSampleRate;
}

- (void)setRfCorrectedRate:(float)rate
{
    _rfCorrectedRate = rate;
    [self calculateResampleRatio];
}

- (float)rfCorrectedRate
{
    return _rfCorrectedRate;
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
    return [IFFilter bandwidth];
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
    return [AFFilter bandwidth];
}

- (void)setAfSkirtWidth:(float)afSkirtWidth
{
    [AFFilter setSkirtWidth:afSkirtWidth];
}

- (float)afSkirtWidth
{
    return [AFFilter skirtWidth];
}

- (float)rfGain
{
    return [IFFilter gain];
}

- (void)setRfGain:(float)rfGain
{
    [IFFilter setGain:rfGain];
}

- (float)afGain
{
    return [AFFilter gain];
}

- (void)setAfGain:(float)afGain
{
    [AFFilter setGain:afGain];
}

- (float)ifMaxBandwidth
{
    return 100000000;
}

- (float)ifMinBandwidth
{
    return      1000;
}

- (float)afMaxBandwidth
{
    return _afSampleRate / 2.;
}

- (float)afMinBandwidth
{
    return 1000;
}

- (float)rfPower
{
    return rfPower;
}

@end
