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

#define ACCELERATE_XLATE
#define ACCELERATE_DEMOD
//#define ACCELERATE_POWER

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
    float *phase = malloc(count * sizeof(float));
    for (int i = 0; i < count; i++) {
        phase[i] = (delta_phase * (float)i) + lastPhase;
        phase[i] = fmod(phase[i], 1.) * 2. * M_PI;
    }
    
    // Vectorized cosine and sines
    DSPSplitComplex coeff;
    coeff.realp = malloc(count * sizeof(float));
    coeff.imagp = malloc(count * sizeof(float));
    vvsinf(coeff.realp, phase, &count);
    vvcosf(coeff.imagp, phase, &count);
//    vvsinpif(coeff.realp, phase, &count);
//    vvcospif(coeff.imagp, phase, &count);
    free(phase);
    
    // Vectorized complex multiplication
    vDSP_zvmul(&input, 1, &coeff, 1, &result, 1, count, 1);
    free(coeff.realp);
    free(coeff.imagp);
    
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

// First, normalize the input vectors to be on the unit circle
    // Compute the magnitude of the vectors
//    float *scalars = malloc(count * sizeof(float));
//    float *mags    = malloc(count * sizeof(float));
    
    // Fill the scalars with zeros for the origin (0,0)
//    vDSP_vclr(scalars, 1, count);
    
    // Calculate the vector distance from the origin (pythagoras)
//    vDSP_vpythg(input.realp, 1, scalars, 1,
//                input.imagp, 1, scalars, 1,
//                mags, 1, count);
    
    // Multiply the input by the inverse of the distance
    // Set the scalar array to 1 for computing the inverse
//    float value = 1.;
//    vDSP_vfill(&value, scalars, 1, count);
    
    // Divide one by the distance to find the scaling value
    // Can we use an input array as the output???
//    vDSP_vdiv(scalars, 1, mags, 1, mags, 1, count);
    
    // Scale the input by the calculated scaling value
//    vDSP_vmul(mags, 1, input.realp, 1, input.realp, 1, count);
//    vDSP_vmul(mags, 1, input.imagp, 1, input.realp, 1, count);
    

// Next, we'll copy the normalized input into another array, shifted
    // to the right one element.  Then, we'll put the "lastsample"
    // into the head element.
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
        
        // Normallize the current element.  This should also
        // normallize the conjugate because it'll already by
        // normallized.
        float length = sqrtf((input.realp[i] * input.realp[i]) +
                             (input.imagp[i] * input.imagp[i]));
        float scalar = 1. / length;
        input.realp[i] = input.realp[i] * scalar;
        input.imagp[i] = input.imagp[i] * scalar;
        
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

void removeDC(NSMutableData *data, double *average, double alpha)
{
    int length = [data length] / sizeof(float);
    float *realSamples = [data mutableBytes];

    // Bootstrap DC offset correction and handle bad floats
    if (!isfinite(*average)) {
        *average = realSamples[0];
    }
    
    // Do the filter
//TODO:  I should be able to use accelerate framework to speed this up
    for (int i = 0; i < length; i++) {
        *average = (*average * (1. - alpha)) + (realSamples[i] * alpha);
        realSamples[i] = realSamples[i] - *average;
    }
}

// requires a 4-element float context array
void getPower(NSDictionary *input, NSMutableData *output, float context[4], double alpha)
{
    NSData *realData = input[@"real"];
    NSData *imagData = input[@"imag"];
    
    int length = [realData length] / sizeof(float);
    const float *realSamples = [realData bytes];
    const float *imagSamples = [imagData bytes];

    COMPLEX_SPLIT complexInput;
    complexInput.realp = (float *)realSamples;
    complexInput.imagp = (float *)imagSamples;
    
    float *outSamples = [output mutableBytes];
//    float tempSamples[length];

#ifdef ACCELERATE_POWER
    float *tempInput  = malloc((length + 2) * sizeof(float));
    float *tempOutput = malloc((length + 2) * sizeof(float));
    
    // Calcluate the magnitudes from the input array (starting at index 2)
    vDSP_zvmags(&complexInput, 1, &tempInput[2], 1, length);
    // Copy the context into the first two spots
    memcpy(tempInput, context, 2 * sizeof(float));
    // Copy the context into the start of the output
    memcpy(tempOutput, &context[2], 2 * sizeof(float));
    
    // Setup the IIR as a 2 pole, 2 zero differential equation
    float coeff[5] = {1. - alpha, 0., 0., -1 * alpha, 0.};
    vDSP_deq22(tempInput, 1, coeff, tempOutput, 1, length);
    
    // Copy the context info out
    memcpy(context, &tempInput[length], 2 * sizeof(float));
    memcpy(&context[2], &tempOutput[length], 2 * sizeof(float));
    
    // Calculate the dbs of the resuling value
    float zeroRef = 1.;
    vDSP_vdbcon(tempSamples, 1, &zeroRef, outSamples, 1, length, 0);
    
    // Copy the results into the output array
    memcpy(tempOutput, tempOutput, length * sizeof(float));
    free(tempInput);
    free(tempOutput);

#else
    float *tempInput  = malloc(length * sizeof(float));
    float *tempOutput = malloc(length * sizeof(float));

    // Calcluate the magnitudes from the input array (starting at index 2)
    vDSP_zvmags(&complexInput, 1, tempInput, 1, length);
    
    // Pre-multiply the magnitudes by alpha using accelerate
    float falpha = alpha;
    vDSP_vsmul(tempInput, 1, &falpha, tempInput, 1, length);
    
    // Compute the power average
    float average = context[0];
    for (int i = 0; i < length; i++) {
        // Magnitude using sum of squares
        float magnitude = tempInput[i];
        
        // Cheezy single-pole IIR low-pass filter
        average = (average * (1. - alpha)) + magnitude;
        tempOutput[i] = average;
    }
    
    // compute the log-10 db
    float zeroRef = 1.;
    vDSP_vdbcon(tempOutput, 1, &zeroRef, outSamples, 1, length, 0);

    // Book keeping
    context[0] = average;
    free(tempInput);
    free(tempOutput);
#endif
}

