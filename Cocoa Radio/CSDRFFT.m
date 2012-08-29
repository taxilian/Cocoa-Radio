//
//  CSDRFFT.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/29/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "dspRoutines.h"
#import <Accelerate/Accelerate.h>
#import <vecLib/vForce.h>

// This function takes an input dictionary with a real and imaginary
// key that contains an NSData encapsulated array of floats.
// There are input samples, each is a full complex number.
// The output is also complex numbers in interleaved format.
// The desired output is the posative/negative frequency format
//- (NSDictionary *)complexFFTOnData:(NSDictionary *)inData
//
// The number of input samples must be a power of two.
//
NSDictionary * complexFFTOnDict(NSDictionary *inDict)
{
    static FFTSetup setup = NULL;
    if (setup == NULL) {
        // Setup the FFT system (accelerate framework)
        setup = vDSP_create_fftsetup(11, FFT_RADIX2);
        if (setup == NULL)
        {
            printf("\nFFT_Setup failed to allocate enough memory.\n");
            exit(0);
        }
    }
    
    // There aren't (to my knowledge) any const versions of this class
    // therefore, we have to cast with the knowledge that these arrays
    // are really consts.
    COMPLEX_SPLIT input;
    input.realp  = (float *)[inDict[@"real"] bytes];
    input.imagp  = (float *)[inDict[@"imag"] bytes];
    
    // Allocate memory for the output operands and check its availability.
    // Results data are 2048 floats (I and Q)
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
    COMPLEX_SPLIT result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    if(result.realp == NULL || result.imagp == NULL ) {
        printf( "\nmalloc failed to allocate memory for the FFT.\n");
        return nil;
    }
    
    // Find the number log2 number of samples
    vDSP_fft_zop(setup, &input, 1, &result, 1, 11, FFT_FORWARD );
    
    // Return the results
    return @{ @"real" : realData,
    @"imag" : imagData };
}

void convertFFTandAverage(NSDictionary *inDict, NSDictionary *fftBufferDict)
{
    NSData *real = inDict[@"real"];
    NSData *imag = inDict[@"imag"];
    
    const float *realData = (const float *)[real bytes];
    const float *imagData = (const float *)[imag bytes];
    
    int width = [real length] / sizeof(float);
    
    float *realBuffer = [fftBufferDict[@"real"] mutableBytes];
    float *imagBuffer = [fftBufferDict[@"imag"] mutableBytes];
    
    // The format of the frequency data is:
    
    //  Positive frequencies | Negative frequencies
    //  [DC][1][2]...[n/2][NY][n/2]...[2][1]  real array
    //  [DC][1][2]...[n/2][NY][n/2]...[2][1]  imag array
    
    // We want the order to be negative frequencies first (descending)
    // And positive frequencies last (ascending)
    
    // Accumulate this data with what came before it, and re-order the values
    for (int i = 0; i <= (width/2); i++) {
        realBuffer[i] += realData[i + (width/2)] / 200.;
        imagBuffer[i] += imagData[i + (width/2)] / 200.;
    }
    
    for (int i = 0; i <  (width/2); i++) {
        realBuffer[i + (width/2)] += realData[i] / 200.;
        imagBuffer[i + (width/2)] += imagData[i] / 200.;
    }
}
