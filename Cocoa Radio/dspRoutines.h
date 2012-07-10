//
//  dspRoutines.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/25/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#ifndef Cocoa_Radio_downconvert_h
#define Cocoa_Radio_downconvert_h

double subtractTimes( uint64_t endTime, uint64_t startTime );

NSDictionary *freqXlate(NSDictionary *inputDict, float localOscillator, int sampleRate);
NSData * quadratureDemod(NSDictionary *inputDict, float gain, float offset);

@interface CSDRfilter : NSObject {
    float _gain;
    float _bandwidth;
    float _skirtWidth;
    int _sampleRate;
    
    NSData *taps;
    NSLock *tapsLock;
    
}

@property (readwrite) float bandwidth;
@property (readwrite) float skirtWidth;
@property (readwrite) float gain;
@property (readwrite) int sampleRate;

@end

@interface CSDRlowPassComplex : CSDRfilter {
    size_t bufferSize;
    NSMutableData *realBuffer;
    NSMutableData *imagBuffer;
}

- (NSDictionary *)filterDict:(NSDictionary *)input;

@end

@interface CSDRlowPassFloat : CSDRfilter {
    size_t bufferSize;
    NSMutableData *buffer;
}

- (NSData *)filterData:(NSData *)input;

@end

#endif
