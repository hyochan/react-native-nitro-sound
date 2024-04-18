#import "React/RCTBridgeModule.h"
#import "RNAudioRecorderPlayer.h"
#import "React/RCTEventEmitter.h"
#import <RNAudioRecorderPlayer-Swift.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <RNAudioRecorderPlayerSpec/RNAudioRecorderPlayerSpec.h>
#endif

//  RNAudioRecorderPlayer.m
//  dooboolab
//
//  Created by dooboolab on 16/04/2018.
//  Copyright © 2018 Facebook. All rights reserved.

@implementation RNAudioRecorderPlayer
RNAudioRecorderPlayerImpl *impl;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (instancetype)init
{
    if (self = [super init]) {
        impl = [[RNAudioRecorderPlayerImpl alloc] init];
        [impl setEmitter:self];
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents
{
    return [impl supportedEvents];
}

RCT_EXPORT_METHOD(setSubscriptionDuration:(double)duration) 
{
    [impl setSubscriptionDuration:duration];
}

RCT_EXPORT_METHOD(startRecorder:(NSString *)path
                  meteringEnabled:(BOOL)meteringEnabled
                  audioSets:(NSDictionary *)audioSets
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) 
{
    [impl startRecorder:path meteringEnabled:meteringEnabled audioSets:audioSets resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(stopRecorder:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl stopRecorder:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(pauseRecorder:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl pauseRecorder:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(resumeRecorder:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl resumeRecorder:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(setVolume:(float)volume
                  resolve:(RCTPromiseResolveBlock) resolve
                  rejecter:(RCTPromiseRejectBlock) reject)
{
    [impl setVolume:volume resolve:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(startPlayer:(NSString*)path
                  httpHeaders:(NSDictionary*)httpHeaders
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl startPlayer:path httpHeaders:httpHeaders resolve:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(resumePlayer:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl resumePlayer:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(seekToPlayer:(double) time
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl seekToPlayer:time resolve:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(pausePlayer:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl pausePlayer:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(stopPlayer:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [impl stopPlayer:resolve rejecter:reject];
}


#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::RNAudioRecorderPlayerSpecJSI>(params);
}
#endif

@end
