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
}

@property (readwrite) float rfSampleRate;
@property (readwrite) float afSampleRate;
@property (readwrite) float rfCorrectedRate;

@property (readwrite) float centerFreq;

@property (readwrite) float ifBandwidth;
@property (readwrite) float ifSkirtWidth;

@property (readwrite) float afBandwidth;
@property (readwrite) float afSkirtWidth;

@property (readwrite) float afGain;
@property (readwrite) float rfGain;

- (NSData *)demodulateData:(NSDictionary *)complexInput;

@end

@interface CSDRDemodFM : CSDRDemod
@end
