//
//  downconvert.c
//  Cocoa Radio
//
//  Created by William Dillon on 6/25/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#include <stdio.h>
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import <vecLib/vForce.h>
#import <mach/mach_time.h>

#include "dspRoutines.h"

//#define ACCELERATE_XLATE
#define ACCELERATE_DEMOD

//Raw mach_absolute_times going in, difference in seconds out
double subtractTimes( uint64_t endTime, uint64_t startTime )
{
	uint64_t difference = endTime - startTime;
	static double conversion = 0.0;
	
	if( conversion == 0.0 )
	{
		mach_timebase_info_data_t info;
		kern_return_t err = mach_timebase_info( &info );
		
		//Convert the timebase into seconds
		if( err == 0  )
			conversion = 1e-9 * (double) info.numer / (double) info.denom;
	}
	
	return conversion * (double) difference;
}

NSDictionary *
createComplexTone(int samples, float sampleRate, float frequency, float *lastPhase)
{
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:samples * sizeof(float)];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:samples * sizeof(float)];
    
    // If provided, copy the input phase
    float phaseOffset = 0.;
    if (lastPhase != nil) {
        phaseOffset = *lastPhase;
    }
    
    float delta_phase = frequency / sampleRate;

    // Create the phase array
    float *phase = malloc(sizeof(float) * samples);
    if (phase == NULL) {
        NSLog(@"Unable to allocate phase array!");
        return nil;
    }
    
    for (int i = 0; i < samples; i++) {
        phase[i] = (delta_phase * (float)i) + phaseOffset;
        phase[i] = fmod(phase[i], 1.) * 2.;
    }
    
    // Vectorized cosine and sines
    float *real = [realData mutableBytes];
    float *imag = [imagData mutableBytes];
    DSPSplitComplex coeff;
    coeff.realp = real;
    coeff.imagp = imag;
    vvsinpif(coeff.realp, phase, &samples);
    vvcospif(coeff.imagp, phase, &samples);

    free(phase);
    
    // If possible, return the last phase
    if (lastPhase != nil) {
        *lastPhase = fmod(samples * delta_phase + phaseOffset, 1.);
    }
    
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData};
}

// This function first "mixes" the input frequency with a local oscillator
// The effect of this is that the desired frequency is moved to 0 Hz.
// Then, the band is low-pass filtered to eliminate unwanted signals
// No decimation is performed at this point.
NSDictionary *
freqXlate(NSDictionary *inputDict, float localOscillator, int sampleRate)
{
    static float lastPhase = 0.;
    float delta_phase = localOscillator / sampleRate;

    NSData *realIn = inputDict[@"real"];
    NSData *imagIn = inputDict[@"imag"];
    
    if (realIn == nil || imagIn == nil) {
        NSLog(@"One or more input to freq xlate was nil");
        return nil;
    }
    
    if ([realIn length] != [imagIn length]) {
        NSLog(@"Size of real and imaginary data arrays don't match.");
    }
    
    int count = [realIn length] / sizeof(float);

    DSPSplitComplex input;
    input.realp = (float *)[inputDict[@"real"] bytes];
    input.imagp = (float *)[inputDict[@"imag"] bytes];
    
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    DSPSplitComplex result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    uint64_t startTime = mach_absolute_time();
    
#ifdef ACCELERATE_XLATE
    // Create the phase and coeff. arrays
    float phase[count];
    for (int i = 0; i < count; i++) {
        phase[i] = (delta_phase * (float)i) + lastPhase;
        phase[i] = fmod(phase[i], 1.) * 2.;
    }
    
    // Vectorized cosine and sines
    float real[count];
    float imag[count];
    DSPSplitComplex coeff;
    coeff.realp = real;
    coeff.imagp = imag;
    vvsinpif(coeff.realp, phase, &count);
    vvcospif(coeff.imagp, phase, &count);
    
    // Vectorized complex multiplication
    vDSP_zvmul(&input, 1, &coeff, 1, &result, 1, count, 1);
    
#else
    const float *inputReal = [inputDict[@"real"] bytes];
    const float *inputImag = [inputDict[@"imag"] bytes];
    
    // Iterate through the array
    for (int i = 0; i < count; i++) {
        // Phase goes from 0 to 1.
        float current_phase = (delta_phase * (float)i) + lastPhase;
        current_phase = fmod(current_phase, 1.);
        
        // Get the local oscillator value for the sample
        // Complex exponential of (2 * pi * j)
        float LOreal = sinf(M_PI * 2 * current_phase);;
        float LOimag = cosf(M_PI * 2 * current_phase);;
        
        const float RFreal = inputReal[i];
        const float RFimag = inputImag[i];
        
        // Complex multiplication (downconversion)
        float first = RFreal * LOreal; // First
        float outer = RFreal * LOimag; // Outer
        float inner = RFimag * LOreal; // Inner
        float last  = RFimag * LOimag; // Last
        
        result.realp[i] = first - last;
        result.imagp[i] = outer + inner;
    }
#endif
    
    uint64_t endTime = mach_absolute_time();
    
    float deltaTime = subtractTimes(endTime, startTime);
    
    static int counter = 0;
    static float runningAverage = 0.;
    
    counter += 1;
    runningAverage += deltaTime;
    
    if (counter == 1000) {
//        NSLog(@"Average runtime: %f", runningAverage / 1000);
        
        counter = 0;
        runningAverage = 0.;
    }
    
    lastPhase = fmod(count * delta_phase + lastPhase, 1.);

    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

NSData *
quadratureDemod(NSDictionary *inputDict, float gain, float offset)
{
    static float lastReal = 0.;
    static float lastImag = 0.;
    
    NSData *realIn = inputDict[@"real"];
    NSData *imagIn = inputDict[@"imag"];
    
    if (realIn == nil || imagIn == nil) {
        NSLog(@"One or more input to freq xlate was nil");
        return nil;
    }
    
    if ([realIn length] != [imagIn length]) {
        NSLog(@"Size of real and imaginary data arrays don't match.");
    }
    
    int count = [realIn length] / sizeof(float);
    
    DSPSplitComplex input;
    input.realp = (float *)[realIn bytes];
    input.imagp = (float *)[imagIn bytes];
    
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    DSPSplitComplex result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    NSMutableData *resultData = [[NSMutableData alloc] initWithLength:count * sizeof(float)];
    float *resultFloats = (float *)[resultData mutableBytes];
    
    uint64_t startTime = mach_absolute_time();
    
#ifdef ACCELERATE_DEMOD
    
    // Quadrature demodulation works by (complex) multiplying
    // the complex conjugate of the previous sample with the current
    
    // Do do this, we'll copy the input in a temporary array,
    // shifted to the right one element.
    // Then, we'll put the "lastsample" into the head
    DSPSplitComplex temp;
    temp.realp = malloc([realIn length]);
    temp.imagp = malloc([imagIn length]);
    temp.realp[0] = lastReal;
    temp.imagp[1] = lastImag;
    memcpy(&temp.realp[1], input.realp, [realIn length] - sizeof(float));
    memcpy(&temp.imagp[1], input.imagp, [imagIn length] - sizeof(float));
    
    // Vectorized complex multiplication
    vDSP_zvmul(&input, 1, &temp, 1, &result, 1, count, -1);
    
    // Vectorized angle computation
    vvatan2f(resultFloats, result.realp, result.imagp, &count);
    
    // Vectorized gain multiplication
    vDSP_vsmsa(resultFloats, 1, &gain, &offset, resultFloats, 1, count);
    
    free(temp.realp);
    free(temp.imagp);
#else
    
    // Iterate through the array
    for (int i = 0; i < count; i++) {
        float conjReal;
        float conjImag;
        
        if (i == 0) {
            conjReal = lastReal;
            conjImag = lastImag * -1.;
        } else {
            conjReal = input.realp[i-1];
            conjImag = input.imagp[i-1] * -1;
        }
        
        const float real = input.realp[i];
        const float imag = input.imagp[i];
        
        // Complex multiplication (downconversion)
        float first = real * conjReal; // First
        float outer = real * conjImag; // Outer
        float inner = imag * conjReal; // Inner
        float last  = imag * conjImag; // Last
        
        float productReal = first - last;
        float productImag = outer + inner;

        float angle = atan2f(productReal, productImag);
        
        resultFloats[i] = angle * gain;
    }
#endif
    
    uint64_t endTime = mach_absolute_time();
    
    float deltaTime = subtractTimes(endTime, startTime);
    
    static int counter = 0;
    static float runningAverage = 0.;
    
    counter += 1;
    runningAverage += deltaTime;
    
    if (counter == 1000) {
//        NSLog(@"Average runtime: %f", runningAverage / 1000);
        
        counter = 0;
        runningAverage = 0.;
    }
    
    lastReal = input.realp[count - 1];
    lastImag = input.imagp[count - 1];
    
    // Return the results
    return resultData;
}
