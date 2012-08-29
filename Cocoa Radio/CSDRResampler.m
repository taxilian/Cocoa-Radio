//
//  CSDRResampler.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRResampler.h"

@implementation CSDRResampler

- (id)init
{
    self = [super init];
    if (self != nil) {
        lastSample = 0.;
        self.interpolator = 1;
        self.decimator = 1;
    }
    
    return self;
}

// This method is a convenience wrapper for the resampleFrom method
- (NSData *)resample:(NSData *)input
{
    int inputSize  = [input  length] / sizeof(float);
    
    int outputSize = (inputSize * self.interpolator) / self.decimator;
    
    NSMutableData *outData = [[NSMutableData alloc] initWithLength:outputSize * sizeof(float)];
    
    [self resampleFrom:input to:outData];
    
    return outData;
}

// The resampler functions by generating a set of virtual
// samples between the input samples, and selecting a subset of
// those as the output.
//
// The last sample instance variable contains the last sample
// of the previous block.  This is used for the first
// interpolation.
//
// A variety of interpolation algorithms could be used.  For now,
// a linear interpolation will be used.
-(void)resampleFrom:(NSData *)input to:(NSMutableData *)output
{
    const float *inputFloats = [input bytes];
    float *outputFloats = [output mutableBytes];
    int inputSize  = [input  length] / sizeof(float);
    int outputSize = [output length] / sizeof(float);
    
    // Make sure that the output array is the correct size.
    if (outputSize != ((inputSize * self.interpolator) / self.decimator)) {
        NSLog(@"Resample array sizes are incompatible with resampling constants!");
        return;
    }
    
    // Make sure that the float arrays aren't null
    if (inputFloats == nil || outputFloats == nil) {
        NSLog(@"At least one byte array passed into resampler was nil!");
        return;
    }
    
    // Perform the main loop for the resampler
    for (int i = 0; i < outputSize; i++) {
        int virtualSampleIndex = i * self.decimator;
        float inputSampleFloat = (float)virtualSampleIndex / (float)(self.interpolator);
        
        // For each output sample, compute its nearest input indices
        int highInputIndex = floorf(inputSampleFloat);
        int lowInputIndex  = highInputIndex - 1;
        
        // Calculate the proportion between the input
        float ratio = inputSampleFloat - highInputIndex;
        
        // Assign the result.  Special case for samples falling
        // the first sample of this block
        if (highInputIndex == 0) {
            outputFloats[i]  = lastSample * ratio;
            outputFloats[i] += inputFloats[highInputIndex] * (1. - ratio);
        } else {
            outputFloats[i]  = inputFloats[lowInputIndex]  * ratio;
            outputFloats[i] += inputFloats[highInputIndex] * (1. - ratio);
        }
    }
    
    // Save the last sample
    lastSample = inputFloats[inputSize - 1];
}

@end