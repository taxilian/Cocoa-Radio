//
//  CSDRFilter.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRFilter.h"

#import <Accelerate/Accelerate.h>
#import <vecLib/vForce.h>
#import <mach/mach_time.h>

#include "dspRoutines.h"

#define ACCELERATE

@implementation CSDRfilter

// This function is derived from the source for GNURadio
// available here: http://gnuradio.org/redmine/projects/gnuradio/repository/revisions/master/entry/gr-filter/lib/firdes.cc
// It, like this project, is licensed under the GPL.
// This implementation is entirely independent and not copied.
// Only the mathematical constructs are the same.
- (void)computeTaps
{
    // Make sure we have everything we need
    if (_sampleRate <= 0. ||
        _skirtWidth <= 0. ||
        _bandwidth  <= 0. ||
        _gain == 0. ||
        _skirtWidth >= (_sampleRate / 2.)) {
        return;
    }
    
    // Determine the number of taps required.
    // Assume the Hamming window for now, which has a width factor of 3.3
    // Do all calculation at double precision
    
    // This block appears correct
    double widthFactor = 3.3;
    double deltaF = (_skirtWidth / _sampleRate);
    int numTaps = (int)(widthFactor / deltaF + .5);
    numTaps += (numTaps % 2 == 0)? 1 : 0; // Enfoce odd number of taps
    
    // Create an NSData object to hold the taps (store only single-precision)
    NSMutableData *tempTaps = [[NSMutableData alloc] initWithLength:numTaps * sizeof(float)];
    float *tapsData = [tempTaps mutableBytes];
    
    // Compute the window coefficients
    int filterOrder = numTaps - 1;
    double *window = malloc(numTaps * sizeof(double));
    for (int i = 0; i < numTaps; i++) {
        window[i] = 0.54 - 0.46 * cos((2 * M_PI * i) / filterOrder);
    }
    // I think the window looks right
    
    // Not sure what this really is, incorperated from GNURadio
    int M = filterOrder / 2;
    double fwT0 = 2 * M_PI * _bandwidth / _sampleRate;
    
    // Calculate the filter taps treat the center as '0'
    for (int i = -M; i <= M; i++) {
        if (i == 0) {
            tapsData[M] = fwT0 / M_PI * window[M];
        } else {
            tapsData[i + M] = sin(i * fwT0) / (i * M_PI) * window[i + M];
        }
    }
    
    double fMax = tapsData[M];
    for (int i = 0; i <= M; i++) {
        fMax += 2 * tapsData[i + M];
    }
    
    // Normalization
    double gain = _gain / fMax;
    for (int i = 0; i < numTaps; i++) {
        tapsData[i] *= gain;
    }
    
    // Update the taps
    [tapsLock lock];
    taps = tempTaps;
    [tapsLock unlock];
    
    free(window);
}

- (float)gain       { return _gain; }
- (float)bandwidth  { return _bandwidth;  }
- (float)skirtWidth { return _skirtWidth; }
- (int)sampleRate   { return _sampleRate; }

- (void)setGain:(float)gain
{
    // Did it really change?
    if (_gain == gain) {
        return;
    }
    
    _gain = gain;
    
    // Re-compute the taps
    [self computeTaps];
}

- (void)setBandwidth:(float)bandwidth
{
    // Did it really change?
    if (_bandwidth == bandwidth) {
        return;
    }
    
    if (_sampleRate < 0.) {
        _bandwidth = bandwidth;
        return;
    }
    
    if (bandwidth <= 0. ||
        bandwidth  > (_sampleRate / 2.)) {
        NSLog(@"Filter bandwidth must be less than half sample rate and greater than zero.");
        return;
    }
    
    _bandwidth = bandwidth;
    
    // Re-compute the taps
    [self computeTaps];
}

- (void)setSkirtWidth:(float)skirtWidth
{
    // Did it really change?
    if (_skirtWidth == skirtWidth) {
        return;
    }
    
    if (skirtWidth <= 0.) {
        NSLog(@"Filter Skirt Width must be greater than zero.");
    }
    
    _skirtWidth = skirtWidth;
    
    // Re-compute the taps
    [self computeTaps];
}

- (void)setSampleRate:(int)sampleRate
{
    // Did it really change?
    if (_sampleRate == sampleRate) {
        return;
    }
    
    if (sampleRate <= 0.) {
        NSLog(@"Sample rate must be greater than zero.");
        return;
    }
    
    _sampleRate = sampleRate;
    
    // Re-compute the taps
    [self computeTaps];
}

@end

@implementation CSDRlowPassComplex

- (id)init
{
    self = [super init];
    if (self) {
        taps = nil;
        tapsLock = [[NSLock alloc] init];
        
        realBuffer = nil;
        imagBuffer = nil;
        
        _sampleRate = -1;
        _skirtWidth = -1;
        _bandwidth = -1;
        _gain = 1;
    }
    
    return self;
}


- (NSDictionary *)filterDict:(NSDictionary *)inputDict

{
    if (taps == nil) {
        NSLog(@"Attempting low-pass filter before configuration");
    }
    
    NSData *realIn = inputDict[@"real"];
    NSData *imagIn = inputDict[@"imag"];
    
    if (realIn == nil || imagIn == nil) {
        NSLog(@"One or more input to freq xlate was nil");
        return nil;
    }
    
    if ([realIn length] != [imagIn length]) {
        NSLog(@"Size of real and imaginary data arrays don't match.");
    }
    
    [tapsLock lock];
    
    // Modify the buffer (if necessary)
    // Create the buffer if one doesn't already exist
    size_t newBufferSize = [taps length];
    if (realBuffer == nil) {
        realBuffer = [[NSMutableData alloc] initWithLength:newBufferSize];
        imagBuffer = [[NSMutableData alloc] initWithLength:newBufferSize];
    } else if (newBufferSize > bufferSize) {
        // Only change the buffer if the number of taps increases
        // We want to increase the size of the buffer, but it's
        // important to ensure that the contents are maintained.
        // The additional data (zeros) should go at the head
        
        // Create the new array
        NSMutableData *tempData = [[NSMutableData alloc] initWithLength:newBufferSize];
        
        // Copy the contents of the old array to the end of the new one
        NSRange range = NSMakeRange(newBufferSize - [realBuffer length], newBufferSize);
        [tempData replaceBytesInRange:range withBytes:[realBuffer bytes]];
        realBuffer = tempData;
        
        tempData = [[NSMutableData alloc] initWithLength:newBufferSize];
        [tempData replaceBytesInRange:range withBytes:[imagBuffer bytes]];
        imagBuffer = tempData;
    }
    
    int count    = [realIn length]   / sizeof(float);
    int numTaps  = [taps   length]   / sizeof(float);
    int capacity = (count + numTaps) * sizeof(float);
    
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    
    COMPLEX_SPLIT result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    if(result.realp == NULL || result.imagp == NULL ) {
        printf( "\nmalloc failed to allocate memory for the FIR.\n");
        return nil;
    }
    
    // Create temporary arrays for FIR processing
    float *real = malloc(capacity);
    float *imag = malloc(capacity);
    bzero(real, capacity);
    bzero(imag, capacity);
    
    // Copy the buffer contents into the temp array
    memcpy(real, [realBuffer bytes], [realBuffer length]);
    memcpy(imag, [imagBuffer bytes], [imagBuffer length]);
    
    // Copy the input into the temp array
    memcpy(&real[numTaps], [realIn bytes], [realIn length]);
    memcpy(&imag[numTaps], [imagIn bytes], [imagIn length]);
    
    // Real and imaginary FIR filtering
    const float *tapsData = [taps bytes];
    vDSP_conv(real, 1, tapsData, 1, result.realp, 1, count, numTaps);
    vDSP_conv(imag, 1, tapsData, 1, result.imagp, 1, count, numTaps);
    
    [tapsLock unlock];
    
    // Refresh the contents of the buffer
    // We need to keep the same number of samples as the number of taps
    memcpy([realBuffer mutableBytes], &real[count], numTaps * sizeof(float));
    memcpy([imagBuffer mutableBytes], &imag[count], numTaps * sizeof(float));
    
    free(real);
    free(imag);
    
    // Return the results
    return @{ @"real" : realData,
    @"imag" : imagData };
}

// Print the taps
-(NSString *)description
{
    NSMutableString *outputString = [[NSMutableString alloc] init];
    
    int num_taps = [taps length] / sizeof(float);
    const float *tapsData = [taps bytes];
    for (int i = 0; i < num_taps; i++) {
        [outputString appendFormat:@"%f, ", tapsData[i]];
    }
    
    // Remove the last ", "
    NSUInteger length = [outputString length];
    NSRange range = NSMakeRange(length - 3, 2);
    [outputString deleteCharactersInRange:range];
    
    return outputString;
}

@end

@implementation CSDRlowPassFloat

- (id)init
{
    self = [super init];
    if (self) {
        taps = nil;
        tapsLock = [[NSLock alloc] init];
        
        buffer = nil;
        
        _sampleRate = -1;
        _skirtWidth = -1;
        _bandwidth = -1;
        _gain = 1;
    }
    
    return self;
}

- (NSData *)filterData:(NSData *)inputData

{
    if (taps == nil) {
        NSLog(@"Attempting low-pass filter before configuration");
    }
    
    if (inputData == nil) {
        NSLog(@"Input data was nil");
        return nil;
    }
    
    [tapsLock lock];
    
    // Modify the buffer (if necessary)
    // Create the buffer if one doesn't already exist
    size_t newBufferSize = [taps length];
    if (buffer == nil) {
        buffer = [[NSMutableData alloc] initWithLength:newBufferSize];
    } else if (newBufferSize > bufferSize) {
        // Only change the buffer if the number of taps increases
        // We want to increase the size of the buffer, but it's
        // important to ensure that the contents are maintained.
        // The additional data (zeros) should go at the head
        
        // Create the new array
        NSMutableData *tempData = [[NSMutableData alloc] initWithLength:newBufferSize];
        
        // Copy the contents of the old array to the end of the new one
        NSRange range = NSMakeRange(newBufferSize - [buffer length], newBufferSize);
        [tempData replaceBytesInRange:range withBytes:[buffer bytes]];
        buffer = tempData;
    }
    
    int count    = [inputData length] / sizeof(float);
    int numTaps  = [taps      length] / sizeof(float);
    int capacity = (count + numTaps)  * sizeof(float);
    
    NSMutableData *outputData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    float *outFloats  = (float *)[outputData mutableBytes];
    
    if(outFloats == NULL) {
        printf( "\nmalloc failed to allocate memory for the FIR.\n");
        return nil;
    }
    
    // Create temporary arrays for FIR processing
    float *temp = malloc(capacity);
    bzero(temp, capacity);
    
    // Copy the buffer contents into the temp array
    memcpy(temp, [buffer bytes], [buffer length]);
    
    // Copy the input into the temp array
    memcpy(&temp[numTaps], [inputData bytes], [inputData length]);
    
    // FIR filtering
    const float *tapsData = [taps bytes];
    vDSP_conv(temp, 1, tapsData, 1, outFloats, 1, count, numTaps);
    
    [tapsLock unlock];
    
    // Refresh the contents of the buffer
    // We need to keep the same number of samples as the number of taps
    memcpy([buffer mutableBytes], &temp[count], numTaps * sizeof(float));
    
    free(temp);
    
    // Return the results
    return outputData;
}

// Print the taps
-(NSString *)description
{
    NSMutableString *outputString = [[NSMutableString alloc] init];
    
    int num_taps = [taps length] / sizeof(float);
    const float *tapsData = [taps bytes];
    for (int i = 0; i < num_taps; i++) {
        [outputString appendFormat:@"%f, ", tapsData[i]];
    }
    
    // Remove the last ", "
    NSUInteger length = [outputString length];
    NSRange range = NSMakeRange(length - 3, 2);
    [outputString deleteCharactersInRange:range];
    
    return outputString;
}

@end