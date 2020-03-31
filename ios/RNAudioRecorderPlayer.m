//  RNAudioRecorderPlayer.m
//  dooboolab
//
//  Created by dooboolab on 16/04/2018.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import "RNAudioRecorderPlayer.h"
#import <React/RCTLog.h>
#import <React/RCTConvert.h>
#import <AVFoundation/AVFoundation.h>

NSString* GetDirectoryOfType_Sound(NSSearchPathDirectory dir) {
  NSArray* paths = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES);
  return [paths.firstObject stringByAppendingString:@"/"];
}

@implementation RNAudioRecorderPlayer {
  NSURL *audioFileURL;
  AVAudioRecorder *audioRecorder;
  AVAudioPlayer *audioPlayer;
  NSTimer *recordTimer;
  NSTimer *playTimer;
}
double subscriptionDuration = 0.1;

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
  NSLog(@"audioPlayerDidFinishPlaying");
  NSNumber *duration = [NSNumber numberWithDouble:audioPlayer.duration * 1000];
  NSNumber *currentTime = [NSNumber numberWithDouble:audioPlayer.duration * 1000];

  // Send last event then finish it.
  // NSString* status = [NSString stringWithFormat:@"{\"duration\": \"%@\", \"current_position\": \"%@\"}", [duration stringValue], [currentTime stringValue]];
  NSDictionary *status = @{
                         @"duration" : [duration stringValue],
                         @"current_position" : [duration stringValue],
                         };
  [self sendEventWithName:@"rn-playback" body: status];
  if (playTimer != nil) {
    [playTimer invalidate];
    playTimer = nil;
  }
}

- (void)updateRecorderProgress:(NSTimer*) timer
{
  NSNumber *currentTime = [NSNumber numberWithDouble:audioRecorder.currentTime * 1000];
  // NSString* status = [NSString stringWithFormat:@"{\"current_position\": \"%@\"}", [currentTime stringValue]];
  NSDictionary *status = @{
                         @"current_position" : [currentTime stringValue],
                         };
  [self sendEventWithName:@"rn-recordback" body:status];
}

- (void)updateProgress:(NSTimer*) timer
{
  NSNumber *duration = [NSNumber numberWithDouble:audioPlayer.duration * 1000];
  NSNumber *currentTime = [NSNumber numberWithDouble:audioPlayer.currentTime * 1000];

  NSLog(@"updateProgress: %@", duration);

  if ([duration intValue] == 0) {
    [playTimer invalidate];
    [audioPlayer stop];
    return;
  }
  
  // NSString* status = [NSString stringWithFormat:@"{\"duration\": \"%@\", \"current_position\": \"%@\"}", [duration stringValue], [currentTime stringValue]];
  NSDictionary *status = @{
                         @"duration" : [duration stringValue],
                         @"current_position" : [currentTime stringValue],
                         };

  [self sendEventWithName:@"rn-playback" body:status];
}

- (void)startRecorderTimer
{
  dispatch_async(dispatch_get_main_queue(), ^{
      self->recordTimer = [NSTimer scheduledTimerWithTimeInterval: subscriptionDuration
                                           target:self
                                           selector:@selector(updateRecorderProgress:)
                                           userInfo:nil
                                           repeats:YES];
  });
}

- (void)startPlayerTimer
{
  dispatch_async(dispatch_get_main_queue(), ^{
      self->playTimer = [NSTimer scheduledTimerWithTimeInterval: subscriptionDuration
                                           target:self
                                           selector:@selector(updateProgress:)
                                           userInfo:nil
                                           repeats:YES];
  });
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"rn-recordback", @"rn-playback"];
}

RCT_EXPORT_METHOD(setSubscriptionDuration:(double)duration
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
  subscriptionDuration = duration;
  resolve(@"set subscription duration.");
}

RCT_EXPORT_METHOD(startRecorder:(NSString*)path
                  audioSets: (NSDictionary*)audioSets
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {

  NSString *encoding = [RCTConvert NSString:audioSets[@"AVFormatIDKeyIOS"]];
  NSNumber *sampleRate = [RCTConvert NSNumber:audioSets[@"AVSampleRateKeyIOS"]];
  NSNumber *numberOfChannel = [RCTConvert NSNumber:audioSets[@"AVNumberOfChannelsKeyIOS"]];
  NSNumber *avFormat;
  NSNumber *audioQuality = [RCTConvert NSNumber:audioSets[@"AVEncoderAudioQualityKeyIOS"]];

  if ([path isEqualToString:@"DEFAULT"]) {
      audioFileURL = [NSURL fileURLWithPath:[GetDirectoryOfType_Sound(NSCachesDirectory) stringByAppendingString:@"sound.m4a"]];
  } else {
      if ([path rangeOfString:@"file://"].location == NSNotFound) {
          audioFileURL = [NSURL fileURLWithPath: [GetDirectoryOfType_Sound(NSCachesDirectory) stringByAppendingString:path]];
      } else {
          audioFileURL = [NSURL URLWithString:path];
      }
  }

  if (!sampleRate) {
      sampleRate = [NSNumber numberWithFloat:44100];
  }
  if (!encoding) {
    avFormat = [NSNumber numberWithInt:kAudioFormatAppleLossless];
  } else {
    if ([encoding  isEqual: @"lpcm"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatLinearPCM];
    } else if ([encoding  isEqual: @"ima4"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatAppleIMA4];
    } else if ([encoding  isEqual: @"aac"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatMPEG4AAC];
    } else if ([encoding  isEqual: @"MAC3"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatMACE3];
    } else if ([encoding  isEqual: @"MAC6"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatMACE6];
    } else if ([encoding  isEqual: @"ulaw"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatULaw];
    } else if ([encoding  isEqual: @"alaw"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatALaw];
    } else if ([encoding  isEqual: @"mp1"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatMPEGLayer1];
    } else if ([encoding  isEqual: @"mp2"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatMPEGLayer2];
    } else if ([encoding  isEqual: @"alac"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatAppleLossless];
    } else if ([encoding  isEqual: @"amr"]) {
      avFormat =[NSNumber numberWithInt:kAudioFormatAMR];
    } else if ([encoding  isEqual: @"flac"]) {
        if (@available(iOS 11, *)) avFormat =[NSNumber numberWithInt:kAudioFormatFLAC];
    } else if ([encoding  isEqual: @"opus"]) {
        if (@available(iOS 11, *)) avFormat =[NSNumber numberWithInt:kAudioFormatOpus];
    }
  }
  if (!numberOfChannel) {
    numberOfChannel = [NSNumber numberWithInt:2];
  }
  if (!audioQuality) {
    audioQuality = [NSNumber numberWithInt:AVAudioQualityMedium];
  }

  NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                 sampleRate, AVSampleRateKey,
                                 avFormat, AVFormatIDKey,
                                 numberOfChannel, AVNumberOfChannelsKey,
                                 audioQuality, AVEncoderAudioQualityKey,
                                 nil];

  // Setup audio session
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

  // set volume default to speaker
  UInt32 doChangeDefaultRoute = 1;
  AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(doChangeDefaultRoute), &doChangeDefaultRoute);

  audioRecorder = [[AVAudioRecorder alloc]
                        initWithURL:audioFileURL
                        settings:audioSettings
                        error:nil];
  
  [audioRecorder setDelegate:self];
  [audioRecorder record];
  [self startRecorderTimer];
    
  NSString *filePath = self->audioFileURL.absoluteString;
  resolve(filePath);
}

RCT_EXPORT_METHOD(stopRecorder:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    if (audioRecorder) {
        [audioRecorder stop];
        if (recordTimer != nil) {
            [recordTimer invalidate];
            recordTimer = nil;
        }

        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];

        NSString *filePath = audioFileURL.absoluteString;
        resolve(filePath);
    } else {
        reject(@"audioRecorder record", @"audioRecorder is not set", nil);
    }
}

RCT_EXPORT_METHOD(setVolume:(double) volume
                  resolve:(RCTPromiseResolveBlock) resolve
                  reject:(RCTPromiseRejectBlock) reject) {
    [audioPlayer setVolume: volume];
    resolve(@"setVolume");
}

RCT_EXPORT_METHOD(startPlayer:(NSString*)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    NSError *error;
    if ([[path substringToIndex:4] isEqualToString:@"http"]) {
        audioFileURL = [NSURL URLWithString:path];

        NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
        dataTaskWithURL:audioFileURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            // NSData *data = [NSData dataWithContentsOfURL:audioFileURL];
            if (!audioPlayer) {
                audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
                audioPlayer.delegate = self;
            }

            // Able to play in silent mode
            [[AVAudioSession sharedInstance]
                setCategory: AVAudioSessionCategoryPlayback
                error: &error];
            // Able to play in background
            [[AVAudioSession sharedInstance] setActive: YES error: nil];
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

            [audioPlayer play];
            [self startPlayerTimer];
            NSString *filePath = audioFileURL.absoluteString;
            resolve(filePath);
        }];

        [downloadTask resume];
    } else {
        if ([path isEqualToString:@"DEFAULT"]) {
          audioFileURL = [NSURL fileURLWithPath:[GetDirectoryOfType_Sound(NSCachesDirectory) stringByAppendingString:@"sound.m4a"]];
        } else {
            if ([path rangeOfString:@"file://"].location == NSNotFound) {
                audioFileURL = [NSURL fileURLWithPath: [GetDirectoryOfType_Sound(NSCachesDirectory) stringByAppendingString:path]];
            } else {
                audioFileURL = [NSURL URLWithString:path];
            }
        }
                
        NSLog(@"Error %@",error);

        if (!audioPlayer) {
            RCTLogInfo(@"audio player alloc");
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL error:nil];
            audioPlayer.delegate = self;
        }

        // Able to play in silent mode
        [[AVAudioSession sharedInstance]
            setCategory: AVAudioSessionCategoryPlayback
            error: nil];

        NSLog(@"Error %@",error);
        [audioPlayer play];
        [self startPlayerTimer];

        NSString *filePath = audioFileURL.absoluteString;
        resolve(filePath);
    }
}

RCT_EXPORT_METHOD(resumePlayer: (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    if (!audioFileURL) {
        reject(@"audioRecorder resume", @"no audioFileURL", nil);
        return;
    }

    if (!audioPlayer) {
        reject(@"audioRecorder resume", @"no audioPlayer", nil);
        return;
    }

    [[AVAudioSession sharedInstance]
        setCategory: AVAudioSessionCategoryPlayback
        error: nil];
    [audioPlayer play];
    [self startPlayerTimer];
    NSString *filePath = audioFileURL.absoluteString;
    resolve(filePath);
}

RCT_EXPORT_METHOD(seekToPlayer: (nonnull NSNumber*) time
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    if (audioPlayer) {
        audioPlayer.currentTime = [time doubleValue];
    } else {
        reject(@"audioPlayer seekTo", @"audioPlayer is not set", nil);
    }
}

RCT_EXPORT_METHOD(pausePlayer: (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    RCTLogInfo(@"pause");
    if (audioPlayer && [audioPlayer isPlaying]) {
        [audioPlayer pause];
        if (playTimer != nil) {
            [playTimer invalidate];
            playTimer = nil;
        } 
        resolve(@"pause play");
    } else {
        reject(@"audioPlayer pause", @"audioPlayer is not playing", nil);
    }
}


RCT_EXPORT_METHOD(stopPlayer:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    if (audioPlayer) {
        if (playTimer != nil) {
            [playTimer invalidate];
            playTimer = nil;
        }
        [audioPlayer stop];
        audioPlayer = nil;
        resolve(@"stop play");
    } else {
        reject(@"audioPlayer stop", @"audioPlayer is not set", nil);
    }
}

@end
