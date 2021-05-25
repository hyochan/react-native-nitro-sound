//
//  RNAudioRecorderPlayer.swift
//  RNAudioRecorderPlayer
//
//  Created by hyochan on 2021/05/05.
//

import Foundation
import AVFoundation

@objc(RNAudioRecorderPlayer)
class RNAudioRecorderPlayer: RCTEventEmitter, AVAudioRecorderDelegate {
    var subscriptionDuration: Double = 0.5
    var audioFileURL: URL?

    // Recorder
    var audioRecorder: AVAudioRecorder!
    var recordingSession: AVAudioSession!
    var recordTimer: Timer?
    var _meteringEnabled: Bool = false

    // Player
    var pausedPlayTime: CMTime?
    var audioPlayerItem: AVPlayerItem!
    var audioPlayer: AVPlayer!
    var playTimer: Timer?
    var timeObserverToken: Any?

    override static func requiresMainQueueSetup() -> Bool {
      return true
    }

    override func supportedEvents() -> [String]! {
        return ["rn-playback", "rn-recordback"]
    }

    func setAudioFileURL(path: String) {
        if (path == "DEFAULT") {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            audioFileURL = cachesDirectory.appendingPathComponent("sound.m4a")
        } else if (path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("file://")) {
            audioFileURL = URL(string: path)
        } else {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            audioFileURL = cachesDirectory.appendingPathComponent(path)
        }
    }

    /**********               Recorder               **********/

    @objc(updateRecorderProgress:)
    public func updateRecorderProgress(timer: Timer) -> Void {
        if (audioRecorder != nil) {
            var currentMetering: Float = 0

            if (_meteringEnabled) {
                audioRecorder.updateMeters()
                currentMetering = audioRecorder.averagePower(forChannel: 0)
            }

            let status = [
                "isRecording": audioRecorder.isRecording,
                "currentPosition": audioRecorder.currentTime * 1000,
                "currentMetering": currentMetering,
            ] as [String : Any];

            sendEvent(withName: "rn-recordback", body: status)
        }
    }

    @objc(startRecorderTimer)
    func startRecorderTimer() -> Void {
        DispatchQueue.main.async {
            self.recordTimer = Timer.scheduledTimer(
                timeInterval: self.subscriptionDuration,
                target: self,
                selector: #selector(self.updateRecorderProgress),
                userInfo: nil,
                repeats: true
            )
        }
    }

    @objc(pauseRecorder:rejecter:)
    public func pauseRecorder(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioRecorder == nil) {
            return reject("RNAudioPlayerRecorder", "Recorder is not recording", nil)
        }

        recordTimer?.invalidate()
        recordTimer = nil;

        audioRecorder.pause()
        resolve("Recorder paused!")
    }

    @objc(resumeRecorder:rejecter:)
    public func resumeRecorder(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioRecorder == nil) {
            return reject("RNAudioPlayerRecorder", "Recorder is nil", nil)
        }

        audioRecorder.record()

        if (recordTimer == nil) {
            startRecorderTimer()
        }

        resolve("Recorder paused!")
    }

    @objc
    func construct() {
        self.subscriptionDuration = 0.1
    }

    @objc(audioPlayerDidFinishPlaying:)
    public static func audioPlayerDidFinishPlaying(player: AVAudioRecorder) -> Bool {
        return true
    }
    
    @objc(setSubscriptionDuration:)
    func setSubscriptionDuration(duration: Double) -> Void {
        subscriptionDuration = duration
    }
    
    /**********               Player               **********/

    @objc(startRecorder:audioSets:meteringEnabled:resolve:reject:)
    func startRecorder(path: String,  audioSets: [String: Any], meteringEnabled: Bool, resolve: @escaping RCTPromiseResolveBlock,
       rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {

        _meteringEnabled = meteringEnabled;

        let encoding = audioSets["AVFormatIDKeyIOS"] as? String
        let avLPCMBitDepth = audioSets["AVLinearPCMBitDepthKeyIOS"] as? Int
        let avLPCMIsBigEndian = audioSets["AVLinearPCMIsBigEndianKeyIOS"] as? Bool
        let avLPCMIsFloatKey = audioSets["AVLinearPCMIsFloatKeyIOS"] as? Bool
        let avLPCMIsNonInterleaved = audioSets["AVLinearPCMIsNonInterleavedIOS"] as? Bool
        
        var avFormat: Int? = nil
        var sampleRate = audioSets["AVSampleRateKeyIOS"] as? Int
        var numberOfChannel = audioSets["AVNumberOfChannelsKeyIOS"] as? Int
        var audioQuality = audioSets["AVEncoderAudioQualityKeyIOS"] as? Int

        setAudioFileURL(path: path)

        if (sampleRate == nil) {
            sampleRate = 44100;
        }

        if (encoding == nil) {
            avFormat = Int(kAudioFormatAppleLossless)
        } else {
            if (encoding == "lpcm") {
                avFormat = Int(kAudioFormatAppleIMA4)
            } else if (encoding == "ima4") {
                avFormat = Int(kAudioFormatAppleIMA4)
            } else if (encoding == "aac") {
                avFormat = Int(kAudioFormatMPEG4AAC)
            } else if (encoding == "MAC3") {
                avFormat = Int(kAudioFormatMACE3)
            } else if (encoding == "MAC6") {
                avFormat = Int(kAudioFormatMACE6)
            } else if (encoding == "ulaw") {
                avFormat = Int(kAudioFormatULaw)
            } else if (encoding == "alaw") {
                avFormat = Int(kAudioFormatALaw)
            } else if (encoding == "mp1") {
                avFormat = Int(kAudioFormatMPEGLayer1)
            } else if (encoding == "mp2") {
                avFormat = Int(kAudioFormatMPEGLayer2)
            } else if (encoding == "alac") {
                avFormat = Int(kAudioFormatAppleLossless)
            } else if (encoding == "amr") {
                avFormat = Int(kAudioFormatAMR)
            } else if (encoding == "flac") {
                if #available(iOS 11.0, *) {
                    avFormat = Int(kAudioFormatFLAC)
                } else if (encoding == "opus") {
                    avFormat = Int(kAudioFormatOpus)
                }
            }
        }

        if (numberOfChannel == nil) {
            numberOfChannel = 2
        }

        if (audioQuality == nil) {
            audioQuality = AVAudioQuality.medium.rawValue
        }

        func startRecording() {
            let settings = [
                AVSampleRateKey: sampleRate!,
                AVFormatIDKey: avFormat!,
                AVNumberOfChannelsKey: numberOfChannel!,
                AVEncoderAudioQualityKey: audioQuality!,
                AVLinearPCMBitDepthKey: avLPCMBitDepth ?? AVLinearPCMBitDepthKey.count,
                AVLinearPCMIsBigEndianKey: avLPCMIsBigEndian ?? true,
                AVLinearPCMIsFloatKey: avLPCMIsFloatKey ?? false,
                AVLinearPCMIsNonInterleaved: avLPCMIsNonInterleaved ?? false
            ] as [String : Any]

            do {
                audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)

                if (audioRecorder != nil) {
                    audioRecorder.prepareToRecord()
                    audioRecorder.delegate = self
                    audioRecorder.isMeteringEnabled = _meteringEnabled
                    audioRecorder.record()
                    startRecorderTimer()

                    resolve(audioFileURL?.absoluteString)
                    return
                }

                reject("RNAudioPlayerRecorder", "Error occured during initiating recorder", nil)
            } catch {
                reject("RNAudioPlayerRecorder", "Error occured during recording", nil)
            }
        }

        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [AVAudioSession.CategoryOptions.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetooth])
            try recordingSession.setActive(true)

            recordingSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        startRecording()
                    } else {
                        reject("RNAudioPlayerRecorder", "Record permission not granted", nil)
                    }
                }
            }
        } catch {
            reject("RNAudioPlayerRecorder", "Faled to record", nil)
        }
    }
    
    @objc(stopRecorder:rejecter:)
    public func stopRecorder(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioRecorder != nil) {
            do {
                audioRecorder.stop()
                try recordingSession.setActive(false)

                if (recordTimer != nil) {
                    recordTimer!.invalidate()
                    recordTimer = nil
                }

                resolve(audioFileURL?.absoluteString)
            } catch {
                reject("RNAudioPlayerRecorder", "Faled to stop recorder", nil)
            }
        }
    }


    /**********               Player               **********/

    func addPeriodicTimeObserver() {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: subscriptionDuration, preferredTimescale: timeScale)

        timeObserverToken = audioPlayer.addPeriodicTimeObserver(forInterval: time,
                                                                queue: .main) {_ in
            self.sendEvent(withName: "rn-playback", body: [
                "isMuted": self.audioPlayer.isMuted,
                "currentPosition": self.audioPlayerItem.currentTime().seconds * 1000,
                "duration": self.audioPlayerItem.duration.seconds * 1000,
            ])
        }
    }

    func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            audioPlayer.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }


    @objc(startPlayer:resolve:rejecter:)
    public func startPlayer(
        path: String,
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        setAudioFileURL(path: path)
        audioPlayerItem = AVPlayerItem(url: audioFileURL!)
        
        if (audioPlayer == nil) {
            audioPlayer = AVPlayer(playerItem: audioPlayerItem)
        } else {
            audioPlayer.replaceCurrentItem(with: audioPlayerItem)
        }

        addPeriodicTimeObserver()
        audioPlayer.play()
        resolve(audioFileURL?.absoluteString)
    }

    @objc(stopPlayer:rejecter:)
    public func stopPlayer(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioPlayer == nil) {
            return reject("RNAudioPlayerRecorder", "Player is already stopped.", nil)
        }

        audioPlayer.pause()
        self.removePeriodicTimeObserver()
        self.audioPlayer = nil;

        resolve(audioFileURL?.absoluteString)
    }

    @objc(pausePlayer:rejecter:)
    public func pausePlayer(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioPlayer == nil) {
            return reject("RNAudioPlayerRecorder", "Player is not playing", nil)
        }

        audioPlayer.pause()
        resolve("Player paused!")
    }

    @objc(resumePlayer:rejecter:)
    public func resumePlayer(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioPlayer == nil) {
            return reject("RNAudioPlayerRecorder", "Player is null", nil)
        }

        audioPlayer.play()
        resolve("Resumed!")
    }

    @objc(seekToPlayer:resolve:rejecter:)
    public func seekToPlayer(
        time: Double,
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioPlayer == nil) {
            return reject("RNAudioPlayerRecorder", "Player is null", nil)
        }

        audioPlayer.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        resolve("Resumed!")
    }

    @objc(setVolume:resolve:rejecter:)
    public func setVolume(
        volume: Float,
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        audioPlayer.volume = volume
        resolve(volume)
    }
}
