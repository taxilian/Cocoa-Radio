//
//  CSDRFilter.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

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
