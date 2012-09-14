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
        // Integer ivars
        counter = 0;
        size = initSize;
        log2n = log2(size);
        if (exp2(log2n) != size) {
            NSLog(@"Non power of 2 input size provided!");
            return nil;
        }

        // Allocate buffers
        realBuffer = malloc(sizeof(double) * initSize);
        imagBuffer = malloc(sizeof(double) * initSize);
        
        // Magnitude data
        magBuffer = [[NSMutableData alloc] initWithLength:sizeof(float) * initSize];
        
        // Processing synchronization and thread
        ringCondition = [[NSCondition alloc] init];
        [ringCondition setName:@"FFT Ring buffer condition"];

        fftThread = [[NSThread alloc] initWithTarget:self
                                            selector:@selector(fftLoop)
                                              object:nil];
        [fftThread setName:@"com.us.alternet.cocoaradio.fftthread"];
        [fftThread start];

        // Ring buffers
        int ringBufferCapacity = initSize * 1000;
        realRingBuffer = [[CSDRRingBuffer alloc] initWithCapacity:ringBufferCapacity];
        imagRingBuffer = [[CSDRRingBuffer alloc] initWithCapacity:ringBufferCapacity];
    }
    
    return self;
}

// This function retreives the current FFT data
// It finalizes the number of FFT operations and divides out the average
- (void)updateMagnitudeData
{
    float *magValues = [magBuffer mutableBytes];

    if (counter == 0) {
        return;
    }
    
    for (int i = 0; i < size; i++) {
        // Compute the average
        double real = realBuffer[i] / counter;
        double imag = imagBuffer[i] / counter;
        
//        real = (double)i / size;
//        imag = (double)(size - i) / size;
        
        // Compute the magnitude and put it in the mag array
        magValues[i] = sqrt((real * real) + (imag * imag));
        magValues[i] = log10(magValues[i]);
        
//        magValues[i] = (float)i / (float)size;
    }

    if (COCOARADIO_FFTCOUNTER_ENABLED()) {
        COCOARADIO_FFTCOUNTER(counter);
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
        NSMutableData *inputRealData =  [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        NSMutableData *inputImagData =  [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        NSMutableData *outputRealData = [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        NSMutableData *outputImagData = [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        
        // This is the threads "forever loop"
        do {
            @autoreleasepool {
                // Get some data from the ring buffer
                [ringCondition lock];
                if ([realRingBuffer fillLevel] < 2048 ||
                    [imagRingBuffer fillLevel] < 2048) {
                    [self updateMagnitudeData];
                    [ringCondition wait];
                }
                
                // Fill the imag and real arrays with data
                [realRingBuffer fillData:inputRealData];
                [imagRingBuffer fillData:inputImagData];
                [ringCondition unlock];
                
                // Perform the FFT
                [self complexFFTinputReal:inputRealData
                                inputImag:inputImagData
                               outputReal:outputRealData
                               outputImag:outputImagData];
                
                // Convert the FFT format and accumulate
                [self convertFFTandAccumulateReal:outputRealData
                                             imag:outputImagData];
                
                // Advance the accumulation counter
                counter++;
            }
        } while (true);
    }
}

- (void)addSamplesReal:(NSData *)real imag:(NSData *)imag
{
    [ringCondition lock];
    
    [realRingBuffer storeData:real];
    [imagRingBuffer storeData:imag];
    
    [ringCondition signal];
    [ringCondition unlock];
}

- (void)complexFFTinputReal:(NSData *)inReal
                  inputImag:(NSData *)inImag
                 outputReal:(NSMutableData *)outReal
                 outputImag:(NSMutableData *)outImag
{
    // Setup the Accelerate framework FFT engine
    static FFTSetup setup = NULL;
    if (setup == NULL) {
        // Setup the FFT system (accelerate framework)
        setup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
        if (setup == NULL)
        {
            printf("\nFFT_Setup failed to allocate enough memory.\n");
            exit(0);
        }
    }
    
    // Check that the inputs are the right size
    int length = size * sizeof(float);
    if ([inReal length]  != length ||
        [inImag length]  != length ||
        [outReal length] != length ||
        [outImag length] != length) {
        NSLog(@"At least one input to the FFT is the wrong size");
        return;
    }
    
    // There aren't (to my knowledge) any const versions of this class
    // therefore, we have to cast with the knowledge that these arrays
    // are really consts.
    COMPLEX_SPLIT input;
    input.realp  = (float *)[inReal bytes];
    input.imagp  = (float *)[inImag bytes];
    
    COMPLEX_SPLIT output;
    output.realp  = (float *)[outReal mutableBytes];
    output.imagp  = (float *)[outImag mutableBytes];
    
    // Make sure that the arrays are accessible
    if (output.realp == NULL || output.imagp == NULL ||
        input.realp  == NULL || input.imagp  == NULL) {
        NSLog(@"Unable to access memory in the FFT function");
        return;
    }
    
    // Perform the FFT
    vDSP_fft_zop(setup, &input, 1, &output, 1, log2n, FFT_FORWARD );

//    int width = [inDict[@"real"] length] / sizeof(float);
//    for (int i = 0; i < width; i++) {
//        result.realp[i] = (float)i / (float)width;
//        result.imagp[i] = (float)(width-i) / (float)width;
//    }
}

- (void)convertFFTandAccumulateReal:(NSMutableData *)real
                               imag:(NSMutableData *)imag
{
    float *realData = [real mutableBytes];
    float *imagData = [imag mutableBytes];
    
//    for (int i = 0; i < size; i++) {
//        realData[i] = (float)i / (float)size;
//        imagData[i] = (float)(size-i) / (float)size;
//    }
    
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
//        realBuffer[i] = realData[i + (size/2)];
//        imagBuffer[i] = imagData[i + (size/2)];
    }
    
    for (int i = 0; i <  (size/2); i++) {
        realBuffer[i + (size/2)] += realData[i];
        imagBuffer[i + (size/2)] += imagData[i];
//        realBuffer[i + (size/2)] = realData[i];
//        imagBuffer[i + (size/2)] = imagData[i];
    }
}

@end