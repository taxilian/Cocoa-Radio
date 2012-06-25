//
//  CSDRAppDelegate.m
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#define CSDRAPPDELEGATE_M
#import "CSDRAppDelegate.h"
#undef  CSDRAPPDELEGATE_M

#import <rtl-sdr/RTLSDRDevice.h>
#import <Accelerate/Accelerate.h>
#import <vecLib/vForce.h>
#import "CSDRSpectrumView.h"
#import "CSDRWaterfallView.h"

//#define ACCELERATE

NSString *CocoaSDRRawDataNotification  = @"CocoaSDRRawDataNotification";
NSString *CocoaSDRFFTDataNotification  = @"CocoaSDRFFTDataNotification";
NSString *CocoaSDRBaseBandNotification = @"CocoaSDRBaseBandNotification";

#define num_taps 339

float taps[num_taps] = {
    6.685296102659777e-05, 0.00010179137461818755, 0.00012970840907655656, 0.0001485004322603345,
    0.0001566241990076378, 0.00015320909733418375, 0.00013813535042572767, 0.00011207209172425792,
    7.647051097592339e-05, 3.350881888763979e-05, -1.4011774510436226e-05, -6.281848618527874e-05,
    -0.00010936065518762916, -0.00015003747830633074, -0.00018144781643059105, -0.0002006473660003394,
    -0.0002053957578027621, -0.0001943743700394407, -0.0001673563674557954, -0.00012531074753496796,
    -7.042599463602528e-05, -6.043139364919625e-06, 6.350569310598075e-05, 0.00013315019896253943,
    0.000197415123693645, 0.0002508153556846082, 0.00028828688664361835, 0.0003056229033973068,
    0.00029987902962602675, 0.00026971352053806186, 0.00021562703477684408, 0.00014007437857799232,
    4.742739474750124e-05, -5.6221506383735687e-05, -0.00016341201262548566, -0.0002658097946550697,
    -0.00035481227678246796, -0.0004222257703077048, -0.00046096363803371787, -0.0004657096869777888,
    -0.0004334886325523257, -0.000364089326467365, -0.00026029394939541817, -0.0001278788549825549,
    2.4629875042592175e-05, 0.00018644548254087567, 0.0003452314995229244, 0.00048799245269037783,
    0.0006020840955898166, 0.0006762684206478298, 0.000701728742569685, 0.0006729600136168301,
    0.0005884498241357505, 0.0004510814615059644, 0.0002682048943825066, 5.134815364726819e-05,
    -0.00018443223962094635, -0.0004215327207930386, -0.0006410575588233769, -0.0008242627372965217,
    -0.0009540821774862707, -0.001016618451103568, -0.001002471661195159, -0.0009077903814613819,
    -0.0007349371444433928, -0.0004926957190036774, -0.00019596851780079305, 0.00013503801892511547,
    0.0004761085147038102, 0.0008007168653421104, 0.0010820147581398487, 0.0012949674855917692,
    0.0014184715691953897, 0.0014372834702953696, 0.0013435921864584088, 0.0011380859650671482,
    0.0008304017246700823, 0.00043887997162528336, -1.0389439921709709e-05, -0.00048519924166612327,
    -0.0009494389523752034, -0.0013657481176778674, -0.0016984193352982402, -0.0019163350807502866,
    -0.0019957006443291903, -0.0019223509589210153, -0.001693414174951613, -0.0013181727845221758,
    -0.0008180051227100194, -0.00022536244068760425, 0.0004181882832199335, 0.0010647509479895234,
    0.0016635404899716377, 0.002164737554267049, 0.002523476490750909, 0.002703654346987605,
    0.0026812569703906775, 0.0024469057098031044, 0.0020073899067938328, 0.001386007061228156,
    0.0006216217298060656, -0.00023354719451162964, -0.0011173076927661896, -0.001961837289854884,
    -0.002698697615414858, -0.0032641629222780466, -0.0036044646985828876, -0.0036805341951549053,
    -0.003471852745860815, -0.0029790548142045736, -0.0022250276524573565, -0.0012543341144919395,
    -0.00013092094741296023, 0.0010658007813617587, 0.002246283460408449, 0.0033172438852488995,
    0.004188696853816509, 0.004781115800142288, 0.005032173823565245, 0.004902530461549759,
    0.0043801660649478436, 0.003482856322079897, 0.002258503809571266, 0.0007831783732399344,
    -0.0008430976886302233, -0.0025026313960552216, -0.004068038892000914, -0.00541141489520669,
    -0.006414071191102266, -0.0069761439226567745, -0.007025343365967274, -0.006524148862808943,
    -0.005474837031215429, -0.00392183568328619, -0.0019510946003720164, 0.000313656433718279,
    0.00271766260266304, 0.005084595642983913, 0.0072281756438314915, 0.008965250104665756,
    0.010129492729902267, 0.010584787465631962, 0.010237340815365314, 0.009045623242855072,
    0.007027320563793182, 0.004262685310095549, 0.0008938480750657618, -0.0028800542932003736,
    -0.006811826024204493, -0.010618837550282478, -0.01399867981672287, -0.01664695516228676,
    -0.018276171758770943, -0.018634533509612083, -0.017523489892482758, -0.014812814071774483,
    -0.010452237911522388, -0.004478727467358112, 0.002981130965054035, 0.011713978834450245,
    0.021427737548947334, 0.031764499843120575, 0.04231764003634453, 0.052652157843112946,
    0.062327150255441666, 0.07091908156871796, 0.07804451137781143, 0.08338090777397156,
    0.08668426424264908, 0.08780259639024734, 0.08668426424264908, 0.08338090777397156,
    0.07804451137781143, 0.07091908156871796, 0.062327150255441666, 0.052652157843112946,
    0.04231764003634453, 0.031764499843120575, 0.021427737548947334, 0.011713978834450245,
    0.002981130965054035, -0.004478727467358112, -0.010452237911522388, -0.014812814071774483,
    -0.017523489892482758, -0.018634533509612083, -0.018276171758770943, -0.01664695516228676,
    -0.01399867981672287, -0.010618837550282478, -0.006811826024204493, -0.0028800542932003736,
    0.0008938480750657618, 0.004262685310095549, 0.007027320563793182, 0.009045623242855072,
    0.010237340815365314, 0.010584787465631962, 0.010129492729902267, 0.008965250104665756,
    0.0072281756438314915, 0.005084595642983913, 0.00271766260266304, 0.000313656433718279,
    -0.0019510946003720164, -0.00392183568328619, -0.005474837031215429, -0.006524148862808943,
    -0.007025343365967274, -0.0069761439226567745, -0.006414071191102266, -0.00541141489520669,
    -0.004068038892000914, -0.0025026313960552216, -0.0008430976886302233, 0.0007831783732399344,
    0.002258503809571266, 0.003482856322079897, 0.0043801660649478436, 0.004902530461549759,
    0.005032173823565245, 0.004781115800142288, 0.004188696853816509, 0.0033172438852488995,
    0.002246283460408449, 0.0010658007813617587, -0.00013092094741296023, -0.0012543341144919395,
    -0.0022250276524573565, -0.0029790548142045736, -0.003471852745860815, -0.0036805341951549053,
    -0.0036044646985828876, -0.0032641629222780466, -0.002698697615414858, -0.001961837289854884,
    -0.0011173076927661896, -0.00023354719451162964, 0.0006216217298060656, 0.001386007061228156,
    0.0020073899067938328, 0.0024469057098031044, 0.0026812569703906775, 0.002703654346987605,
    0.002523476490750909, 0.002164737554267049, 0.0016635404899716377, 0.0010647509479895234,
    0.0004181882832199335, -0.00022536244068760425, -0.0008180051227100194, -0.0013181727845221758,
    -0.001693414174951613, -0.0019223509589210153, -0.0019957006443291903, -0.0019163350807502866,
    -0.0016984193352982402, -0.0013657481176778674, -0.0009494389523752034, -0.00048519924166612327,
    -1.0389439921709709e-05, 0.00043887997162528336, 0.0008304017246700823, 0.0011380859650671482,
    0.0013435921864584088, 0.0014372834702953696, 0.0014184715691953897, 0.0012949674855917692,
    0.0010820147581398487, 0.0008007168653421104, 0.0004761085147038102, 0.00013503801892511547,
    -0.00019596851780079305, -0.0004926957190036774, -0.0007349371444433928, -0.0009077903814613819,
    -0.001002471661195159, -0.001016618451103568, -0.0009540821774862707, -0.0008242627372965217,
    -0.0006410575588233769, -0.0004215327207930386, -0.00018443223962094635, 5.134815364726819e-05,
    0.0002682048943825066, 0.0004510814615059644, 0.0005884498241357505, 0.0006729600136168301,
    0.000701728742569685, 0.0006762684206478298, 0.0006020840955898166, 0.00048799245269037783,
    0.0003452314995229244, 0.00018644548254087567, 2.4629875042592175e-05, -0.0001278788549825549,
    -0.00026029394939541817, -0.000364089326467365, -0.0004334886325523257, -0.0004657096869777888,
    -0.00046096363803371787, -0.0004222257703077048, -0.00035481227678246796, -0.0002658097946550697,
    -0.00016341201262548566, -5.6221506383735687e-05, 4.742739474750124e-05, 0.00014007437857799232,
    0.00021562703477684408, 0.00026971352053806186, 0.00029987902962602675, 0.0003056229033973068,
    0.00028828688664361835, 0.0002508153556846082, 0.000197415123693645, 0.00013315019896253943,
    6.350569310598075e-05, -6.043139364919625e-06, -7.042599463602528e-05, -0.00012531074753496796,
    -0.0001673563674557954, -0.0001943743700394407, -0.0002053957578027621, -0.0002006473660003394,
    -0.00018144781643059105, -0.00015003747830633074, -0.00010936065518762916, -6.281848618527874e-05,
    -1.4011774510436226e-05, 3.350881888763979e-05, 7.647051097592339e-05, 0.00011207209172425792,
    0.00013813535042572767, 0.00015320909733418375, 0.0001566241990076378, 0.0001485004322603345,
    0.00012970840907655656, 0.00010179137461818755, 6.685296102659777e-05};

@implementation CSDRAppDelegate

@synthesize window = _window;

// This function takes an input dictionary with a real and imaginary
// key that contains an NSData encapsulated array of floats.
// There are 2048 samples, each is a full complex number.
// The output is 2048 complex numbers in interleaved format.
// The desired output is the posative/negative frequency format
//- (NSDictionary *)complexFFTOnData:(NSDictionary *)inData
- (NSDictionary *)complexFFTOnDict:(NSDictionary *)inDict
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
    
    COMPLEX_SPLIT input;
    input.realp  = [inDict[@"real"] mutableBytes];
    input.imagp  = [inDict[@"imag"] mutableBytes];

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

    // Forward FFT (2048 elements log2 = 11
    vDSP_fft_zop ( setup, &input, 1, &result, 1, 11, FFT_FORWARD );
    
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

// This function first "mixes" the input frequency with a local oscillator
// The effect of this is that the desired frequency is moved to 0 Hz.
// Then, the band is low-pass filtered to eliminate unwanted signals
// No decimation is performed at this point.
- (NSDictionary *)freqXlateDict:(NSDictionary *)inputDict
{
    static float lastPhase = 0.;
    int count = 2048;
    float localOscillator = [[self waterfallView] tuningValue];
    float sampleRate = 2048000;
    float delta_phase = localOscillator / sampleRate;
    
    DSPSplitComplex input;
    input.realp = (float *)[inputDict[@"real"] bytes];
    input.imagp = (float *)[inputDict[@"imag"] bytes];

    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    DSPSplitComplex result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];

#ifdef ACCELERATE
    // Create the phase and coeff. arrays
    float *phase = malloc(count * sizeof(float));
    for (int i = 0; i < count; i++) {
        phase[i] = (delta_phase * (float)i) + lastPhase;
        phase[i] = fmod(phase[i], 1.) * 2.;
    }
    
    // Vectorized cosine and sines
    DSPSplitComplex coeff;
    coeff.realp = malloc(count * sizeof(float));
    coeff.imagp = malloc(count * sizeof(float));
    vvsinpif(coeff.realp, phase, &count);
    vvcospif(coeff.imagp, phase, &count);
    
    // Vectorized complex multiplication
    vDSP_zvmul(&input, 1, &coeff, 1, &result, 1, count, 1);

    lastPhase = fmod(count * delta_phase, 1.);
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
    
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

        // Real part of the product
        result.realp[i] = first - last;
//        outputValues[i * 2 + 0] = first - last;
        
        // Imaginary part of the product
        result.imagp[i] = outer + inner;
//        outputValues[i * 2 + 1] = outer + inner;
    }
#endif
    
    lastPhase = fmod(count * delta_phase, 1.);
    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

- (NSDictionary *)lowPassFilterDict:(NSDictionary *)inputDict

{
    int count = 2048;
    int capacity = (count + num_taps) * sizeof(float);

    static float *real = nil;
    static float *imag = nil;

    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];

    COMPLEX_SPLIT result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    if(result.realp == NULL || result.imagp == NULL ) {
        printf( "\nmalloc failed to allocate memory for the FIR.\n");
        return nil;
    }
    
    // if this is the first time, do some init/special cases
    if (real == nil) {
        real = malloc(capacity);
        bzero(real, capacity);
    }
    if (imag == nil) {
        imag = malloc(capacity);
        bzero(imag, capacity);
    }
    
    // Move the last (num_taps) of the last values into the beginning
    // of the working array
    memcpy(real, &real[count - num_taps], num_taps * sizeof(float));
    memcpy(imag, &imag[count - num_taps], num_taps * sizeof(float));
    // Copy the input into the remaining part
    memcpy(real, [inputDict[@"real"] bytes], count * sizeof(float));
    memcpy(imag, [inputDict[@"imag"] bytes], count * sizeof(float));
    
    // Real and imaginary FIR filtering
    vDSP_conv(real, 1, taps, 1, result.realp, 1, count, num_taps);
    vDSP_conv(imag, 1, taps, 1, result.imagp, 1, count, num_taps);

    // Return the results
    return @{ @"real" : realData,
              @"imag" : imagData };
}

- (void)readLoop
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [device resetEndpoints];
    
    float *buffer = malloc(2048 * 2 * sizeof(float));
    
    do {
        @autoreleasepool {
            // Perform the read (2048 samples, one byte for I and Q)
            NSData *resultData = [device readSychronousLength:4096];
            if (resultData == nil) {
                NSApplication *app = [NSApplication sharedApplication];
                [app stop:self];
            }

            const uint8_t *resultSamples = [resultData bytes];

            // Results data are 2048 floats (I and Q)
            NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
            NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * 2048];
            
            // Convert the samples from bytes to floats between -1 and 1
            // and split them into seperate I and Q arrays
            COMPLEX_SPLIT input;
            input.realp  = (float *)[realData mutableBytes];
            input.imagp  = (float *)[imagData mutableBytes];
            for (int i = 0; i < 2048; i++) {
                input.realp[i] = (float)(resultSamples[i*2 + 0] - 127) / 128;
                input.imagp[i] = (float)(resultSamples[i*2 + 1] - 127) / 128;
            }
            NSDictionary *complexRaw = @{ @"real" : realData,
                                          @"imag" : imagData };

            // Down convert
            NSDictionary *baseBand = [self freqXlateDict:complexRaw];
            
            // Low-pass filter
            NSDictionary *filtered = [self lowPassFilterDict:baseBand];

            // The resultData is new data from the device
            // Create a notification with the raw data
            [center postNotificationName:CocoaSDRRawDataNotification
                                  object:complexRaw];
            
            // Schedule an FFT of the new data
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                NSDictionary *fftDict = [self complexFFTOnDict:complexRaw];
                NSDictionary *fftDict = [self complexFFTOnDict:baseBand];
//                NSDictionary *fftDict = [self complexFFTOnDict:filtered];
                [center postNotificationName:CocoaSDRFFTDataNotification
                                      object:fftDict];
            });
            
//            // Schedule a downconversion and filter
//            // The active demodulator will subscribe to this notification
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                NSData *baseBand = [self computeBaseBand:resultData];
//                [center postNotificationName:CocoaSDRBaseBandNotification
//                                      object:baseBand];
//            });
        }
    } while (true);
        
    free(buffer);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setTuningValue:144.370];
    [self setBottomValue:0.];
    [self setRange:1.];
    [self setAverage:16];
    
    // Instanciate an RTL SDR device (choose the first)
    device = [[RTLSDRDevice alloc] initWithDeviceIndex:0];
    if (device == nil) {
        // Display an error and close
        NSAlert *alert = [NSAlert alertWithMessageText:@"Unable to open device"
                                         defaultButton:@"Close"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Cocoa Radio was unable to open the RTL Tuner, check its connection and try again."];
        // Wait for the user to click it
        [alert runModal];
        
        // Shut down the app
        NSApplication *app = [NSApplication sharedApplication];
        [app stop:self];
        return;
    }

    // Set the sample rate and tuning
    [device setSampleRate:2048000];
    [device setCenterFreq:tuningValue];
    
    [[self waterfallView] setSampleRate:2048000];
    
    // Create a thread for reading
    readThread = [[NSThread alloc] initWithTarget:self
                                         selector:@selector(readLoop)
                                           object:nil];
    [readThread start];
    
    // Setup the shared context for the spectrum and waterfall views
    [[self waterfallView] initialize];
    [[self spectrumView] shareContextWithController:[self waterfallView]];
    [[self spectrumView] initialize];
    
    return;
}

- (float)tuningValue
{
    return tuningValue;
}

- (float)loValue
{
    return loValue;
}

- (void)setLoValue:(float)newLoValue
{
    [device setCenterFreq:(newLoValue * 1000000)];
    loValue = [device centerFreq];
    
    float tValue = loValue + [[self waterfallView] tuningValue];
    [self setTuningValue:tValue / 1000000.];
}

- (void)setTuningValue:(float)newTuningValue
{
//    [[self tuningField] setFloatValue:newTuningValue];
    tuningValue = newTuningValue;
    return;
}

@end
