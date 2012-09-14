//
//  CSDRFFT.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRRingBuffer;

@interface CSDRFFT : NSObject {
    double *realBuffer;
    double *imagBuffer;
    
    int counter;
    int size;
    int log2n;
    
    NSMutableData *magBuffer;
    
    NSCondition *ringCondition;
    NSThread *fftThread;
    
    CSDRRingBuffer *realRingBuffer;
    CSDRRingBuffer *imagRingBuffer;
}

@property (readonly) NSData *magBuffer;

- (id)initWithSize:(int)size;

- (void)addSamplesReal:(NSData *)real imag:(NSData *)imag;

- (void)updateMagnitudeData;

@end
