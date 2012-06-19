//
//  SpectrumView.h
//  Spectrum Analyzer
//
//  Created by William Dillon on 2/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CSDRAppDelegate.h"

@class Document;
@class SpectrumController;

@interface CSDRSpectrumView : NSView
{
    @private
    
    // Cached value
    NSSize nativePixelsInGraph;
    
    // Current FFT Data
    NSData *fftData;
}

// This provides access to the number of native device pixels
// in the interior of the graph.  It can be used to sample the
// experiment at the perfect resolution
@property(readonly) NSSize nativePixelsInGraph;

@property (readwrite) IBOutlet CSDRAppDelegate *appDelegate;

@end