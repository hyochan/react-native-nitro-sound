#import <React/RCTEventEmitter.h>
#import <AVFoundation/AVFoundation.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <RNAudioRecorderPlayerSpec/RNAudioRecorderPlayerSpec.h>

@interface RNAudioRecorderPlayer : RCTEventEmitter <NativeAudioRecorderPlayerSpec>

#else
#import <React/RCTBridgeModule.h>

@interface RNAudioRecorderPlayer : RCTEventEmitter <RCTBridgeModule>

#endif

@end
