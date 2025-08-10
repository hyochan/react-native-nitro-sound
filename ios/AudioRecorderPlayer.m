#import "AudioRecorderPlayer.h"
#import <React/RCTBridge.h>
#import <React/RCTConvert.h>

@interface AudioRecorderPlayer () <AVAudioRecorderDelegate, AVAudioPlayerDelegate>
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, strong) NSDate *recordingStartTime;
@property (nonatomic, strong) NSDate *playbackStartTime;
@end

@implementation AudioRecorderPlayer

RCT_EXPORT_MODULE(AudioRecorderPlayer)

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"rn-recordback", @"rn-playback", @"rn-playback-end"];
}

- (void)startObserving {
    NSLog(@"startObserving called - setting hasListeners to YES");
    self.hasListeners = YES;
}

- (void)stopObserving {
    NSLog(@"stopObserving called - setting hasListeners to NO");
    self.hasListeners = NO;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _subscriptionDuration = 0.06;
    }
    return self;
}

// MARK: - Recording Methods

RCT_EXPORT_METHOD(startRecorder:(NSString *)uri 
                     audioSets:(NSDictionary *)audioSets 
               meteringEnabled:(NSNumber *)meteringEnabled 
                       resolve:(RCTPromiseResolveBlock)resolve 
                        reject:(RCTPromiseRejectBlock)reject) {
    
    NSError *error;
    
    // Setup audio session
    self.recordingSession = [AVAudioSession sharedInstance];
    [self.recordingSession setCategory:AVAudioSessionCategoryPlayAndRecord 
                                   mode:AVAudioSessionModeDefault 
                                options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth
                                  error:&error];
    
    if (error) {
        NSLog(@"Audio session setup error: %@", error.localizedDescription);
        reject(@"audio_session_error", [NSString stringWithFormat:@"Failed to setup audio session: %@", error.localizedDescription], error);
        return;
    }
    
    [self.recordingSession setActive:YES error:&error];
    if (error) {
        NSLog(@"Audio session activation error: %@", error.localizedDescription);
        reject(@"audio_session_error", [NSString stringWithFormat:@"Failed to activate audio session: %@", error.localizedDescription], error);
        return;
    }
    
    // Request permission
    [self.recordingSession requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                NSLog(@"Microphone permission granted");
                [self setupAndStartRecordingWithURI:uri 
                                          audioSets:audioSets 
                                    meteringEnabled:meteringEnabled 
                                            resolve:resolve 
                                             reject:reject];
            } else {
                NSLog(@"Microphone permission denied");
                reject(@"permission_denied", @"Recording permission denied. Please enable microphone access in Settings.", nil);
            }
        });
    }];
}

- (void)setupAndStartRecordingWithURI:(NSString *)uri 
                            audioSets:(NSDictionary *)audioSets 
                      meteringEnabled:(NSNumber *)meteringEnabled 
                              resolve:(RCTPromiseResolveBlock)resolve 
                               reject:(RCTPromiseRejectBlock)reject {
    
    @try {
        NSURL *fileURL;
        if (uri && [uri length] > 0) {
            fileURL = [NSURL fileURLWithPath:uri];
            NSLog(@"Using provided URI: %@", uri);
        } else {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *fileName = [NSString stringWithFormat:@"sound_%f.m4a", [[NSDate date] timeIntervalSince1970]];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
            fileURL = [NSURL fileURLWithPath:filePath];
            NSLog(@"Generated file path: %@", filePath);
        }
        
        // Delete existing file if it exists
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            [fileManager removeItemAtPath:[fileURL path] error:nil];
            NSLog(@"Deleted existing file at path: %@", [fileURL path]);
        }
        
        // Setup audio settings with more compatible values
        NSMutableDictionary *settings = [NSMutableDictionary dictionary];
        
        // Use more compatible settings
        [settings setObject:@(kAudioFormatMPEG4AAC) forKey:AVFormatIDKey];
        [settings setObject:@(44100.0) forKey:AVSampleRateKey];
        [settings setObject:@(1) forKey:AVNumberOfChannelsKey]; // Use mono for better compatibility
        [settings setObject:@(AVAudioQualityMedium) forKey:AVEncoderAudioQualityKey];
        [settings setObject:@(128000) forKey:AVEncoderBitRateKey]; // Add bit rate
        
        // Apply custom settings if provided
        if (audioSets && audioSets[@"AVNumberOfChannelsKeyIOS"]) {
            [settings setObject:audioSets[@"AVNumberOfChannelsKeyIOS"] forKey:AVNumberOfChannelsKey];
        }
        if (audioSets && audioSets[@"AVEncoderAudioQualityKeyIOS"]) {
            [settings setObject:audioSets[@"AVEncoderAudioQualityKeyIOS"] forKey:AVEncoderAudioQualityKey];
        }
        
        NSLog(@"Audio settings: %@", settings);
        
        NSError *error = nil;
        self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:settings error:&error];
        
        if (error || !self.audioRecorder) {
            NSLog(@"Recorder initialization error: %@", error ? error.localizedDescription : @"Unknown error");
            reject(@"recorder_init_error", 
                   [NSString stringWithFormat:@"Failed to initialize recorder: %@", error ? error.localizedDescription : @"Unknown error"], 
                   error);
            return;
        }
        
        self.audioRecorder.meteringEnabled = meteringEnabled ? [meteringEnabled boolValue] : NO;
        self.audioRecorder.delegate = nil; // Clear any existing delegate
        
        BOOL prepareSuccess = [self.audioRecorder prepareToRecord];
        if (!prepareSuccess) {
            NSLog(@"Failed to prepare recorder");
            reject(@"recording_failed", @"Failed to prepare recording", nil);
            return;
        }
        
        BOOL recordSuccess = [self.audioRecorder record];
        if (recordSuccess) {
            NSLog(@"Recording started successfully at path: %@", [fileURL path]);
            self.recordingStartTime = [NSDate date];
            self.actualRecordedDuration = 0;
            
            // Start timer for recording updates
            [self startRecordTimer];
            
            resolve([fileURL path]);
        } else {
            NSLog(@"Failed to start recording");
            reject(@"recording_failed", @"Failed to start recording. Please check microphone permissions.", nil);
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception in setupAndStartRecordingWithURI: %@", exception.reason);
        reject(@"recording_exception", [NSString stringWithFormat:@"Recording exception: %@", exception.reason], nil);
    }
}

RCT_EXPORT_METHOD(pauseRecorder:(RCTPromiseResolveBlock)resolve 
                          reject:(RCTPromiseRejectBlock)reject) {
    if (self.audioRecorder && self.audioRecorder.isRecording) {
        [self stopRecordTimer];
        [self.audioRecorder pause];
        resolve(@"Recording paused");
    } else {
        reject(@"not_recording", @"No active recording to pause", nil);
    }
}

RCT_EXPORT_METHOD(resumeRecorder:(RCTPromiseResolveBlock)resolve 
                           reject:(RCTPromiseRejectBlock)reject) {
    if (self.audioRecorder && !self.audioRecorder.isRecording) {
        [self.audioRecorder record];
        [self startRecordTimer];
        resolve(@"Recording resumed");
    } else {
        reject(@"not_paused", @"Recording is not paused", nil);
    }
}

RCT_EXPORT_METHOD(stopRecorder:(RCTPromiseResolveBlock)resolve 
                         reject:(RCTPromiseRejectBlock)reject) {
    if (self.audioRecorder) {
        [self stopRecordTimer];
        NSURL *fileURL = self.audioRecorder.url;
        NSString *filePath = [fileURL path];
        
        // Stop the recorder
        [self.audioRecorder stop];
        
        // Get the actual file duration after recording stops
        double actualDuration = 0;
        NSError *error = nil;
        AVAudioPlayer *tempPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
        if (tempPlayer && !error) {
            actualDuration = tempPlayer.duration * 1000; // Convert to milliseconds
        }
        
        self.audioRecorder = nil;
        self.recordingStartTime = nil;
        self.actualRecordedDuration = 0;
        
        // Return an object with both file path and duration
        NSDictionary *result = @{
            @"filePath": filePath,
            @"duration": @(actualDuration)
        };
        resolve(result);
    } else {
        reject(@"not_recording", @"No active recording to stop", nil);
    }
}

// MARK: - Playback Methods

RCT_EXPORT_METHOD(startPlayer:(NSString *)uri 
                   httpHeaders:(NSDictionary *)httpHeaders 
                       resolve:(RCTPromiseResolveBlock)resolve 
                        reject:(RCTPromiseRejectBlock)reject) {
    
    NSLog(@"startPlayer called with URI: %@", uri);
    
    NSURL *fileURL;
    if (!uri || [uri length] == 0) {
        // If no URI provided, try to play the last recorded file
        if (self.audioRecorder && self.audioRecorder.url) {
            fileURL = self.audioRecorder.url;
            NSLog(@"Using last recorded file: %@", [fileURL path]);
        } else {
            reject(@"invalid_uri", @"No URI provided and no recording available", nil);
            return;
        }
    } else if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        fileURL = [NSURL URLWithString:uri];
        NSLog(@"Using remote URL: %@", uri);
    } else {
        fileURL = [NSURL fileURLWithPath:uri];
        NSLog(@"Using local file path: %@", uri);
    }
    
    // Check if file exists for local files
    if (![uri hasPrefix:@"http://"] && ![uri hasPrefix:@"https://"]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:[fileURL path]]) {
            NSLog(@"File does not exist at path: %@", [fileURL path]);
            reject(@"file_not_found", [NSString stringWithFormat:@"File not found at path: %@", [fileURL path]], nil);
            return;
        }
        NSLog(@"File exists at path: %@", [fileURL path]);
    }
    
    NSError *error;
    
    // Setup audio session for playback
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error) {
        reject(@"audio_session_error", @"Failed to set audio session category", error);
        return;
    }
    
    [session setActive:YES error:&error];
    if (error) {
        reject(@"audio_session_error", @"Failed to activate audio session", error);
        return;
    }
    
    // Initialize player
    if (uri && ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"])) {
        // For remote files, use AVPlayer or similar approach
        // This is a simplified implementation
        NSLog(@"Downloading remote file...");
        NSData *data = [NSData dataWithContentsOfURL:fileURL];
        if (data) {
            NSLog(@"Downloaded %lu bytes", (unsigned long)data.length);
            self.audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
        } else {
            NSLog(@"Failed to download remote file");
            reject(@"download_failed", @"Failed to download audio file", nil);
            return;
        }
    } else {
        NSLog(@"Initializing player with local file...");
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
    }
    
    if (error) {
        NSLog(@"Player initialization error: %@", error.localizedDescription);
        reject(@"player_init_error", [NSString stringWithFormat:@"Failed to initialize player: %@", error.localizedDescription], error);
        return;
    }
    
    if (!self.audioPlayer) {
        NSLog(@"Player is nil after initialization");
        reject(@"player_init_error", @"Player initialization returned nil", nil);
        return;
    }
    
    NSLog(@"Player initialized successfully, duration: %f seconds", self.audioPlayer.duration);
    
    // Set delegate
    self.audioPlayer.delegate = self;
    
    BOOL prepareSuccess = [self.audioPlayer prepareToPlay];
    NSLog(@"Prepare to play: %@", prepareSuccess ? @"success" : @"failed");
    
    // Get exact duration after prepare
    NSTimeInterval exactDuration = self.audioPlayer.duration;
    NSLog(@"Exact duration after prepare: %f seconds", exactDuration);
    
    // Log current hasListeners state before starting playback
    NSLog(@"Current hasListeners state before playback: %@", self.hasListeners ? @"YES" : @"NO");
    
    if ([self.audioPlayer play]) {
        NSLog(@"Playback started successfully");
        NSLog(@"Player state - isPlaying: %@, duration: %f, volume: %f", 
              self.audioPlayer.isPlaying ? @"YES" : @"NO",
              self.audioPlayer.duration,
              self.audioPlayer.volume);
        self.playbackStartTime = [NSDate date];
        
        // Call updatePlaybackProgress immediately to send initial state
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updatePlaybackProgress];
        });
        
        [self startPlayTimer];
        resolve([fileURL absoluteString]);
    } else {
        NSLog(@"Failed to start playback");
        self.audioPlayer = nil;
        reject(@"playback_failed", @"Failed to start playback", nil);
    }
}

RCT_EXPORT_METHOD(stopPlayer:(RCTPromiseResolveBlock)resolve 
                       reject:(RCTPromiseRejectBlock)reject) {
    NSLog(@"stopPlayer called - audioPlayer: %@", self.audioPlayer ? @"exists" : @"nil");
    
    if (self.audioPlayer) {
        [self stopPlayTimer];
        [self.audioPlayer stop];
        self.audioPlayer = nil;
        self.playbackStartTime = nil;
        NSLog(@"Player stopped successfully");
        resolve(@"Player stopped");
    } else {
        NSLog(@"No audio player to stop");
        reject(@"not_playing", @"No active playback to stop", nil);
    }
}

RCT_EXPORT_METHOD(pausePlayer:(RCTPromiseResolveBlock)resolve 
                        reject:(RCTPromiseRejectBlock)reject) {
    NSLog(@"pausePlayer called - audioPlayer: %@, isPlaying: %@", 
          self.audioPlayer ? @"exists" : @"nil", 
          self.audioPlayer.isPlaying ? @"YES" : @"NO");
    
    if (self.audioPlayer) {
        [self stopPlayTimer];
        [self.audioPlayer pause];
        NSLog(@"Playback paused successfully");
        resolve(@"Playback paused");
    } else {
        NSLog(@"No audio player instance");
        reject(@"not_playing", @"No active playback to pause", nil);
    }
}

RCT_EXPORT_METHOD(resumePlayer:(RCTPromiseResolveBlock)resolve 
                         reject:(RCTPromiseRejectBlock)reject) {
    NSLog(@"resumePlayer called - audioPlayer: %@, isPlaying: %@", 
          self.audioPlayer ? @"exists" : @"nil", 
          self.audioPlayer.isPlaying ? @"YES" : @"NO");
    
    if (self.audioPlayer) {
        BOOL success = [self.audioPlayer play];
        if (success) {
            [self startPlayTimer];
            NSLog(@"Playback resumed successfully");
            resolve(@"Playback resumed");
        } else {
            NSLog(@"Failed to resume playback");
            reject(@"resume_failed", @"Failed to resume playback", nil);
        }
    } else {
        NSLog(@"No audio player instance");
        reject(@"not_paused", @"No audio player to resume", nil);
    }
}

RCT_EXPORT_METHOD(seekToPlayer:(double)time 
                        resolve:(RCTPromiseResolveBlock)resolve 
                         reject:(RCTPromiseRejectBlock)reject) {
    if (self.audioPlayer) {
        self.audioPlayer.currentTime = time / 1000.0; // Convert ms to seconds
        resolve(@"Seek completed");
    } else {
        reject(@"not_playing", @"No active playback", nil);
    }
}

RCT_EXPORT_METHOD(setVolume:(double)volume 
                     resolve:(RCTPromiseResolveBlock)resolve 
                      reject:(RCTPromiseRejectBlock)reject) {
    if (self.audioPlayer) {
        self.audioPlayer.volume = volume;
        resolve(@"Volume set");
    } else {
        reject(@"not_playing", @"No active playback", nil);
    }
}

RCT_EXPORT_METHOD(setPlaybackSpeed:(double)speed 
                            resolve:(RCTPromiseResolveBlock)resolve 
                             reject:(RCTPromiseRejectBlock)reject) {
    if (self.audioPlayer) {
        if (@available(iOS 10.0, *)) {
            self.audioPlayer.rate = speed;
            resolve(@"Playback speed set");
        } else {
            reject(@"not_supported", @"Playback speed not supported on this iOS version", nil);
        }
    } else {
        reject(@"not_playing", @"No active playback", nil);
    }
}

// MARK: - Subscription

RCT_EXPORT_METHOD(setSubscriptionDuration:(double)sec) {
    self.subscriptionDuration = sec;
}

// MARK: - Timer Methods

- (void)startRecordTimer {
    [self stopRecordTimer];
    
    self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:self.subscriptionDuration
                                                        target:self
                                                      selector:@selector(updateRecordingProgress)
                                                      userInfo:nil
                                                       repeats:YES];
    
    // Add timer to run loop to ensure it fires
    [[NSRunLoop mainRunLoop] addTimer:self.recordTimer forMode:NSRunLoopCommonModes];
}

- (void)stopRecordTimer {
    if (self.recordTimer) {
        [self.recordTimer invalidate];
        self.recordTimer = nil;
    }
}

- (void)updateRecordingProgress {
    if (self.audioRecorder && self.audioRecorder.isRecording) {
        [self.audioRecorder updateMeters];
        
        NSTimeInterval currentTime = self.audioRecorder.currentTime * 1000; // Convert to milliseconds
        NSTimeInterval recordTime = currentTime;
        self.actualRecordedDuration = recordTime; // Keep track of actual recorded time
        
        float averagePower = [self.audioRecorder averagePowerForChannel:0];
        float peakPower = [self.audioRecorder peakPowerForChannel:0];
        
        if (self.hasListeners) {
            NSDictionary *recordingData = @{
                @"currentPosition": @(recordTime),
                @"currentMetering": @(averagePower),
                @"currentPeakMetering": @(peakPower)
            };
            
            [self sendEventWithName:@"rn-recordback" body:recordingData];
        }
    }
}

- (void)startPlayTimer {
    [self stopPlayTimer];
    
    NSLog(@"Starting play timer with interval: %f", self.subscriptionDuration);
    
    // Create timer
    self.playTimer = [NSTimer timerWithTimeInterval:self.subscriptionDuration
                                              target:self
                                            selector:@selector(updatePlaybackProgress)
                                            userInfo:nil
                                             repeats:YES];
    
    // Add timer to main run loop with common modes to ensure it fires
    [[NSRunLoop mainRunLoop] addTimer:self.playTimer forMode:NSRunLoopCommonModes];
    
    if (self.playTimer) {
        NSLog(@"Play timer started successfully and added to run loop");
        // Fire immediately once
        [self.playTimer fire];
    } else {
        NSLog(@"Failed to create play timer");
    }
}

- (void)stopPlayTimer {
    if (self.playTimer) {
        NSLog(@"Stopping play timer");
        [self.playTimer invalidate];
        self.playTimer = nil;
    }
}

- (void)updatePlaybackProgress {
    if (!self.audioPlayer) {
        NSLog(@"Warning: updatePlaybackProgress called but audioPlayer is nil");
        [self stopPlayTimer];
        return;
    }
    
    NSTimeInterval currentTime = self.audioPlayer.currentTime * 1000; // Convert to milliseconds
    NSTimeInterval duration = self.audioPlayer.duration * 1000;
    
    NSDictionary *playbackData = @{
        @"currentPosition": @(currentTime),
        @"duration": @(duration)
    };
    
    if (self.hasListeners) {
        [self sendEventWithName:@"rn-playback" body:playbackData];
    }
    
    // Check if playback ended
    if (!self.audioPlayer.isPlaying && currentTime >= duration - 100) { // Within 100ms of end
        NSLog(@"Playback ended - stopping timer");
        [self stopPlayTimer];
    }
}

// MARK: - Listeners (Bridge compatibility)

RCT_EXPORT_METHOD(addRecordBackListener:(RCTResponseSenderBlock)callback) {
    // For compatibility, but we use event emitter instead
}

RCT_EXPORT_METHOD(removeRecordBackListener) {
    // For compatibility, but we use event emitter instead
}

RCT_EXPORT_METHOD(addPlayBackListener:(RCTResponseSenderBlock)callback) {
    // For compatibility, but we use event emitter instead
}

RCT_EXPORT_METHOD(removePlayBackListener) {
    // For compatibility, but we use event emitter instead
}

// MARK: - Utility Methods

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, mmss:(double)secs) {
    NSInteger seconds = (NSInteger)secs;
    NSInteger minutes = seconds / 60;
    seconds = seconds % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, mmssss:(double)milisecs) {
    NSInteger totalSeconds = (NSInteger)(milisecs / 1000);
    NSInteger minutes = totalSeconds / 60;
    NSInteger seconds = totalSeconds % 60;
    NSInteger milliseconds = ((NSInteger)milisecs % 1000) / 10;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)minutes, (long)seconds, (long)milliseconds];
}

// MARK: - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"Audio player finished playing, success: %@", flag ? @"YES" : @"NO");
    [self stopPlayTimer];
    
    if (self.hasListeners) {
        NSDictionary *endData = @{
            @"finished": @(YES),
            @"duration": @(player.duration * 1000),
            @"currentPosition": @(player.duration * 1000)
        };
        [self sendEventWithName:@"rn-playback-end" body:endData];
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    NSLog(@"Audio player decode error: %@", error.localizedDescription);
    [self stopPlayTimer];
}

@end