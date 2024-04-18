#import <React/RCTEventEmitter.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <RNAudioRecorderPlayerSpec/RNAudioRecorderPlayerSpec.h>

@interface RNAudioRecorderPlayer : RCTEventEmitter <NativeCalculatorSpec, AVAudioPlayerDelegate>
#else
@interface RNAudioRecorderPlayer : RCTEventEmitter <RCTBridgeModule, AVAudioPlayerDelegate>
#endif
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error;
- (void)updateRecorderProgress:(NSTimer*) timer;

@end
