//
//  CSDRDemod.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRlowPassComplex;
@class CSDRlowPassFloat;
@class CSDRResampler;

@interface CSDRDemod : NSObject {
    CSDRlowPassComplex *IFFilter;
    CSDRlowPassFloat   *AFFilter;
    CSDRResampler      *AFResampler;
    
    float _rfSampleRate;
    float _afSampleRate;
    
    float _rfCorrectedRate;
    
    double average;
    
    float demodGain;
 
    float rfPower;
    double powerContext;
    NSMutableData *radioPower;
}

- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate;

@property (readwrite) float rfSampleRate;
@property (readwrite) float afSampleRate;
@property (readwrite) float rfCorrectedRate;

@property (readwrite) float centerFreq;

@property (readonly)  float ifMinBandwidth;
@property (readonly)  float ifMaxBandwidth;
@property (readwrite) float ifBandwidth;
@property (readwrite) float ifSkirtWidth;

@property (readonly)  float afMinBandwidth;
@property (readonly)  float afMaxBandwidth;
@property (readwrite) float afBandwidth;
@property (readwrite) float afSkirtWidth;

@property (readwrite) float afGain;
@property (readwrite) float rfGain;

@property (readonly)  float rfPower;
@property (readwrite) float squelch;

- (NSData *)demodulateData:(NSDictionary *)complexInput;

+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme;

@end

@interface CSDRDemodWBFM : CSDRDemod
@end

@interface CSDRDemodNBFM : CSDRDemod
@end
