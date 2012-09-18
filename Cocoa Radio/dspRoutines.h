//
//  dspRoutines.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/25/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#ifndef Cocoa_Radio_downconvert_h
#define Cocoa_Radio_downconvert_h

#import <Cocoa/Cocoa.h>

#import "CSDRFilter.h"
#import "CSDRResampler.h"
#import "CSDRDemod.h"

@class AudioSink;

double subtractTimes( uint64_t endTime, uint64_t startTime );

NSDictionary *freqXlate(NSDictionary *inputDict, float localOscillator, int sampleRate);
NSData *quadratureDemod(NSDictionary *inputDict, float gain, float offset);
NSDictionary *createComplexTone(int samples, float sampleRate, float frequency, float *lastPhase);

// Bootstrap the process by setting average = NAN
void removeDC(NSMutableData *data, double *average, double alpha);

// Calculate power level from the given signal (log 10)
void getPower(NSDictionary *input, NSMutableData *output, double *context, double alpha);

#endif
