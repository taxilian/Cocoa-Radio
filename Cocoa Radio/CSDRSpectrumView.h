//
//  SpectrumView.h
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import <Cocoa/Cocoa.h>
#import "CSDRAppDelegate.h"
#import "OpenGLController.h"
#import "ShaderProgram.h"

@class Document;
@class SpectrumController;

@interface CSDRSpectrumView : OpenGLController
{
    @private
    bool initialized;
    
    // Cached value
    NSSize nativePixelsInGraph;
    
    GLint textureID;
    ShaderProgram *shader;
    
    // Current FFT Data
    NSData *fftData;
}

// This provides access to the number of native device pixels
// in the interior of the graph.  It can be used to sample the
// experiment at the perfect resolution
@property(readonly) NSSize nativePixelsInGraph;

@property (readwrite) IBOutlet CSDRAppDelegate *appDelegate;

- (void)initialize;

- (void)update;

@end
