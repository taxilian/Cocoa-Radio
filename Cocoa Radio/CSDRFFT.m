//
//  CSDRFFT.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/29/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRFFT.h"
#import "CSDRRingBuffer.h"

#import "delegateprobes.h"

#import <Accelerate/Accelerate.h>
#import <vecLib/vForce.h>

@implementation CSDRFFT

- (id)initWithSize:(int)initSize
{
    self = [super init];
    if (self) {
        // Allocate buffers
        realBuffer = malloc(sizeof(double) * initSize);
        imagBuffer = malloc(sizeof(double) * initSize);
        
        // Magnitude data
        magBuffer = [[NSMutableData alloc] initWithLength:sizeof(float) * initSize];
        
        // Integer ivars
        size = initSize;
        counter = 0;
        
        // Processing thread
        ringCondition = [[NSCondition alloc] init];
        fftThread = [[NSThread alloc] initWithTarget:self
                                            selector:@selector(fftLoop)
                                              object:nil];
        [fftThread start];

        // Ring buffers
        int ringBufferCapacity = initSize * 1000;
        realRingBuffer = [[CSDRRingBuffer alloc] initWithCapacity:ringBufferCapacity];
        imagRingBuffer = [[CSDRRingBuffer alloc] initWithCapacity:ringBufferCapacity];
    }
    
    return self;
}

- (void)convertFFTandAccumulate:(NSDictionary *)inDict
{
    NSMutableData *real = inDict[@"real"];
    NSMutableData *imag = inDict[@"imag"];
    
    //    const float *realData = (const float *)[real bytes];
    //    const float *imagData = (const float *)[imag bytes];
    float *realData = [real mutableBytes];
    float *imagData = [imag mutableBytes];
    
    for (int i = 0; i < size; i++) {
        realData[i] = (float)i / (float)size;
        imagData[i] = (float)(size-i) / (float)size;
    }
    
    // The format of the frequency data is:
    
    //  Positive frequencies  | Negative frequencies
    //  [DC][1][2]...[n/2][NY]|[n/2]...[2][1]  real array
    //  [DC][1][2]...[n/2][NY]|[n/2]...[2][1]  imag array
    
    // We want the order to be negative frequencies first (descending)
    // And positive frequencies last (ascending)
    
    // Accumulate this data with what came before it, and re-order the values
    for (int i = 0; i <= (size/2); i++) {
        realBuffer[i] += realData[i + (size/2)];
        imagBuffer[i] += imagData[i + (size/2)];
        //        realBuffer[i] = realData[i + (width/2)];
        //        imagBuffer[i] = imagData[i + (width/2)];
    }
    
    for (int i = 0; i <  (size/2); i++) {
        realBuffer[i + (size/2)] += realData[i];
        imagBuffer[i + (size/2)] += imagData[i];
        //        realBuffer[i + (width/2)] = realData[i];
        //        imagBuffer[i + (width/2)] = imagData[i];
    }
}

// This function retreives the current FFT data
// It finalizes the number of FFT operations and divides out the average
- (void)updateMagnitudeData
{
    float *magValues = [magBuffer mutableBytes];

    for (int i = 0; i < size; i++) {
        // Compute the average
        double real = realBuffer[i] / counter;
        double imag = imagBuffer[i] / counter;
        
//        real = (double)i / size.;
//        imag = (double)(size - i) / size.;
        
        // Compute the magnitude and put it in the mag array
        magValues[i] = sqrt((real * real) + (imag * imag));
        magValues[i] = log10(magValues[i]);
        
//        magValues[i] = (float)i / size.;
    }

    counter = 0;

    bzero(realBuffer, size * sizeof(double));
    bzero(imagBuffer, size * sizeof(double));
}

- (NSData *)magBuffer
{
    return magBuffer;
}

- (void)fftLoop
{
    @autoreleasepool {
        NSMutableData *realData = [[NSMutableData alloc] initWithCapacity:2048 * sizeof(float)];
        NSMutableData *imagData = [[NSMutableData alloc] initWithCapacity:2048 * sizeof(float)];
        
        // This is the threads "forever loop"
        do {
            @autoreleasepool {
                // Get some data from the ring buffer
                [ringCondition lock];
                if ([realRingBuffer fillLevel] < 2048 ||
                    [imagRingBuffer fillLevel] < 2048) {
                    [ringCondition wait];
                }
                
                // Fill the imag and real arrays with data
                [realRingBuffer fillData:realData];
                [imagRingBuffer fillData:imagData];
                [ringCondition unlock];
                
                // Perform the FFT
                NSDictionary *fftResult = complexFFTOnDict(@{ @"real" : realData,
                                                              @"imag" : imagData});
                
                // Convert the FFT format and accumulate
                [self convertFFTandAccumulate:fftResult];
                
                // Advance the accumulation counter
                counter++;
                
                if (COCOARADIO_FFTCOUNTER_ENABLED()) {
                    COCOARADIO_FFTCOUNTER(counter);
                }
            }
        } while (true);
    }
}

- (void)addSamplesReal:(NSData *)real imag:(NSData *)imag
{
    
}

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

//    int width = [inDict[@"real"] length] / sizeof(float);
//    for (int i = 0; i < width; i++) {
//        result.realp[i] = (float)i / (float)width;
//        result.imagp[i] = (float)(width-i) / (float)width;
//    }
    
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

@end