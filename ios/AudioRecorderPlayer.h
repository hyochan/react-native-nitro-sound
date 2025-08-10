#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioRecorderPlayer : RCTEventEmitter <RCTBridgeModule, AVAudioPlayerDelegate, AVAudioRecorderDelegate>

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *audioPlayerNode;
@property (nonatomic, strong) AVAudioFile *audioFile;

@property (nonatomic, strong) NSTimer *recordTimer;
@property (nonatomic, strong) NSTimer *playTimer;

@property (nonatomic, assign) NSTimeInterval subscriptionDuration;
@property (nonatomic, strong) AVAudioSession *recordingSession;
@property (nonatomic, assign) NSTimeInterval actualRecordedDuration;

@end