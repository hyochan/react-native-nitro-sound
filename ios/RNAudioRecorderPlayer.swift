//
//  RNAudioRecorderPlayer.swift
//  RNAudioRecorderPlayer
//
//  Created by hyochan on 2021/05/05.
//

import Foundation
import AVFoundation
import QuartzCore

enum RecorderError: LocalizedError {
    case notRecording
    case alreadyRecording
    case failedToResumeRecording
    case recordingFormatNotAvailable
    case failedToLocateRecordingFile
    case failedToCreateRecorder
    case failedToStartRecording
    case recordingPermissionNotGranted
    case audioSessionError(Error)

    public var errorDescription: String? {
        switch self {
        case .notRecording:
            return "Recorder is not recording"
        case .alreadyRecording:
            return "Recorder is already recording"
        case .failedToResumeRecording:
            return "Failed to resume recording"
        case .recordingFormatNotAvailable:
            return "Recording format not available"
        case .failedToLocateRecordingFile:
            return "Failed to locate recording file"
        case .failedToCreateRecorder:
            return "Failed to create recorder"
        case .failedToStartRecording:
            return "Failed to start recording"
        case .recordingPermissionNotGranted:
            return "Recording permission not granted"
        case .audioSessionError(let error):
            return error.localizedDescription
        }
    }
}

@objc(RNAudioRecorderPlayer)
class RNAudioRecorderPlayer: RCTEventEmitter, AVAudioRecorderDelegate {
    // MARK: - Constants
    
    /// Delay before resuming recording after an audio interruption ends.
    /// This workaround is necessary because some SDKs (e.g., Twilio) erroneously call
    /// `setActive(false)` shortly after the interruption ends (~100ms observed in logs).
    /// The delay ensures the audio session is fully stabilized before reactivation.
    private let interruptionRecoveryDelay: TimeInterval = 0.5
    
    // MARK: - Properties
    
    var audioSession: AVAudioSession = .sharedInstance()
    var subscriptionDuration: Double = 0.5
    var audioFileURL: URL?

    // Recorder
    var currentAudioRecorder: AVAudioRecorder?
    var recordTimer: Timer? {
        didSet { oldValue?.invalidate() }
    }
    var _meteringEnabled: Bool = false
    // Duration of current recording up until it was last resumed
    var accumulatedRecordingDuration: Double = 0
    // Used to keep track of the total recording duration, accounting for pausing and resuming
    var lastResumeTime: Double?
    // Track if we were recording when an interruption began
    var wasRecordingBeforeInterruption: Bool = false

    // Player
    var pausedPlayTime: CMTime?
    var audioPlayerAsset: AVURLAsset!
    var audioPlayerItem: AVPlayerItem!
    var audioPlayer: AVPlayer!
    var timeObserverToken: Any?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override static func requiresMainQueueSetup() -> Bool {
      return true
    }

    override func supportedEvents() -> [String]! {
        return ["rn-playback", "rn-recordback", "rn-recording-state"]
    }

    func updateAudioFileURL(path: String, format: AudioFormatID = kAudioFormatMPEG4AAC) {
        if (path == "DEFAULT") {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            audioFileURL = cachesDirectory.appendingPathComponent("sound.\(fileExtension(forAudioFormat: format))")
        } else if (path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("file://")) {
            audioFileURL = URL(string: path)
        } else {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            audioFileURL = cachesDirectory.appendingPathComponent(path)
        }
    }

    /**********               Recorder               **********/

    @objc(startRecorder:audioSets:meteringEnabled:resolve:reject:)
    func startRecorder(path: String,  audioSets: [String: Any], meteringEnabled: Bool, resolve: @escaping RCTPromiseResolveBlock,
       rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        startNewRecording(path: path, audioSets: audioSets, meteringEnabled: meteringEnabled) { result in
            switch result {
            case .success(let url):
                self.sendEvent(withName: "rn-recording-state", body: ["state": "recording"])
                resolve(url.absoluteString)
            case .failure(let error):
                reject("RNAudioPlayerRecorder", error.localizedDescription, error)
            }
        }
    }

    @objc(pauseRecorder:rejecter:)
    public func pauseRecorder(resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        do {
            try pauseCurrentRecording()
            sendEvent(withName: "rn-recording-state", body: ["state": "paused"])
            resolve("Recorder paused!")
        } catch {
            reject("RNAudioPlayerRecorder", error.localizedDescription, error)
        }
    }

    @objc(resumeRecorder:rejecter:)
    public func resumeRecorder(resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        do {
            try resumeCurrentRecording()
            sendEvent(withName: "rn-recording-state", body: ["state": "recording"])
            resolve("Recorder resumed!")
        } catch {
            reject("RNAudioPlayerRecorder", error.localizedDescription, error)
        }
    }

    @objc(stopRecorder:rejecter:)
    public func stopRecorder(resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        finishCurrentRecording { result in
            switch result {
            case .success(let url):
                self.sendEvent(withName: "rn-recording-state", body: ["state": "stopped"])
                resolve(url.absoluteString)
            case .failure(let error):
                reject("RNAudioPlayerRecorder", error.localizedDescription, error)
            }
        }
    }

    @objc(updateRecorderProgress:)
    public func updateRecorderProgress(timer: Timer) -> Void {
        guard let currentAudioRecorder else { return }

        var currentMetering: Float = 0
        if (_meteringEnabled) {
            currentAudioRecorder.updateMeters()
            currentMetering = currentAudioRecorder.averagePower(forChannel: 0)
        }
        let status = [
            "isRecording": currentAudioRecorder.isRecording,
            "currentPosition": getCurrentRecordingDuration() * 1000,
            "currentMetering": currentMetering,
        ] as [String : Any];
        sendEvent(withName: "rn-recordback", body: status)
    }

    @objc(startRecorderTimer)
    func startRecorderTimer() -> Void {
        let timer = Timer(
            timeInterval: self.subscriptionDuration,
            target: self,
            selector: #selector(self.updateRecorderProgress),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .default)
        self.recordTimer = timer
    }

    @objc
    func construct() {
        self.subscriptionDuration = 0.1
    }

    @objc(audioPlayerDidFinishPlaying:)
    public static func audioPlayerDidFinishPlaying(player: AVAudioRecorder) -> Bool {
        return true
    }

    @objc(audioPlayerDecodeErrorDidOccur:)
    public static func audioPlayerDecodeErrorDidOccur(error: Error?) -> Void {
        print("Playing failed with error")
        print(error ?? "")
        return
    }

    @objc(setSubscriptionDuration:)
    func setSubscriptionDuration(duration: Double) -> Void {
        subscriptionDuration = duration
    }

    // handle interrupt events
    @objc
    func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt
        else { return }

        switch interruptionType {
        case AVAudioSession.InterruptionType.began.rawValue:
            // Capture whether we had an active recording so we can decide to resume later
            wasRecordingBeforeInterruption = currentAudioRecorder?.isRecording ?? false
            guard wasRecordingBeforeInterruption else { break }

            do {
                try pauseCurrentRecording()
                sendEvent(withName: "rn-recording-state", body: ["state": "interrupted"])
            } catch {
                // We don't expect it to fail to pause the recording
            }
            break
        case AVAudioSession.InterruptionType.ended.rawValue:
            // Only send events if we were recording before the interruption
            guard wasRecordingBeforeInterruption else { break }

            // Only attempt to resume if the system indicates it is allowed
            let options = AVAudioSession.InterruptionOptions(rawValue: userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            if options.contains(.shouldResume) {
                // Delay before resuming to avoid conflicts with third-party SDKs that may
                // deactivate the audio session shortly after the interruption ends (looking at you, Twilio)
                DispatchQueue.main.asyncAfter(deadline: .now() + interruptionRecoveryDelay) {
                    do {
                        try self.resumeCurrentRecording()
                        self.sendEvent(withName: "rn-recording-state", body: ["state": "recording"])
                    } catch {
                        self.sendEvent(withName: "rn-recording-state", body: ["state": "paused"])
                    }
                }
            } else {
                sendEvent(withName: "rn-recording-state", body: ["state": "paused"])
            }
            wasRecordingBeforeInterruption = false
            break
        default:
            break
        }
    }

    private func startNewRecording(path: String, audioSets: [String: Any], meteringEnabled: Bool, completion: @escaping (Result<URL, RecorderError>) -> Void) {
        guard currentAudioRecorder == nil else { return completion(.failure(.alreadyRecording)) }

        _meteringEnabled = meteringEnabled
        guard
            let avFormat: AudioFormatID = avFormat(fromString: audioSets["AVFormatIDKeyIOS"] as? String ?? "alac")
        else { return completion(.failure(.recordingFormatNotAvailable)) }

        let settings = [
            AVSampleRateKey: audioSets["AVSampleRateKeyIOS"] as? Int ?? 44100,
            AVFormatIDKey: avFormat,
            AVNumberOfChannelsKey: audioSets["AVNumberOfChannelsKeyIOS"] as? Int ?? 2,
            AVEncoderAudioQualityKey: audioSets["AVEncoderAudioQualityKeyIOS"] as? Int ?? AVAudioQuality.medium.rawValue,
            AVLinearPCMBitDepthKey: audioSets["AVLinearPCMBitDepthKeyIOS"] as? Int ?? AVLinearPCMBitDepthKey.count,
            AVLinearPCMIsBigEndianKey: audioSets["AVLinearPCMIsBigEndianKeyIOS"] as? Bool ?? true,
            AVLinearPCMIsFloatKey: audioSets["AVLinearPCMIsFloatKeyIOS"] as? Bool ?? false,
            AVLinearPCMIsNonInterleaved: audioSets["AVLinearPCMIsNonInterleavedIOS"] as? Bool ?? false,
            AVEncoderBitRateKey: audioSets["AVEncoderBitRateKeyIOS"] as? Int ?? 128000
        ] as [String: Any]

        updateAudioFileURL(path: path, format: avFormat)
        let avMode = avMode(fromString: audioSets["AVModeIOS"] as? String ?? "default") ?? .default

        // Configure audio session options
        var categoryOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .mixWithOthers]
        // Check if Bluetooth input should be allowed (defaults to true for backward compatibility)
        let allowBluetoothInput = audioSets["AVAllowBluetoothInputIOS"] as? Bool ?? true
        if allowBluetoothInput {
            categoryOptions.insert(.allowBluetooth)
        }

        do {
            try audioSession.setPrefersNoInterruptionsFromSystemAlerts(true)
            try audioSession.setCategory(.playAndRecord, mode: avMode, options: categoryOptions)
            try audioSession.setActive(true)
        } catch {
            return completion(.failure(.audioSessionError(error)))
        }
        audioSession.requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else { return completion(.failure(.recordingPermissionNotGranted)) }
                guard let audioFileURL = self.audioFileURL else { return completion(.failure(.failedToLocateRecordingFile)) }
                guard let audioRecorder = try? AVAudioRecorder(url: audioFileURL, settings: settings) else { return completion(.failure(.failedToCreateRecorder)) }

                audioRecorder.prepareToRecord()
                audioRecorder.delegate = self
                audioRecorder.isMeteringEnabled = meteringEnabled
                guard audioRecorder.record() else { return completion(.failure(.failedToStartRecording)) }

                self.currentAudioRecorder = audioRecorder
                self.recordingDidStart()
                self.startRecorderTimer()
                completion(.success(audioFileURL))
            }
        }
    }

    private func pauseCurrentRecording() throws {
        recordTimer = nil;
        guard let currentAudioRecorder else { throw RecorderError.notRecording }

        currentAudioRecorder.pause()
        self.recordingDidPause()
    }

    private func resumeCurrentRecording() throws {
        guard let currentAudioRecorder else { throw RecorderError.notRecording }

        // Reactivate session
        do {
            try audioSession.setActive(true)
        } catch {
            print("[RNAudioRecorderPlayer] Failed to reactivate audio session: \(error.localizedDescription)")
            throw RecorderError.audioSessionError(error)
        }

        // Resume recording
        if currentAudioRecorder.record() == false {
            print("[RNAudioRecorderPlayer] Failed to resume recording")
            throw RecorderError.failedToResumeRecording
        }

        self.recordingDidResume()
        if (self.recordTimer == nil) {
            self.startRecorderTimer()
        }
    }

    private func finishCurrentRecording(completion: @escaping (Result<URL, RecorderError>) -> Void) {
        recordTimer = nil
        DispatchQueue.main.async {
            guard let currentAudioRecorder = self.currentAudioRecorder else { return completion(.failure(.notRecording)) }
            guard let audioFileURL = self.audioFileURL else { return completion(.failure(.failedToLocateRecordingFile)) }

            currentAudioRecorder.stop()
            self.recordingDidFinish()
            self.currentAudioRecorder = nil
            // Deactivate audio session when finished recording
            do {
                try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                completion(.success(audioFileURL))
            } catch {
                completion(.failure(.audioSessionError(error)))
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Failed to stop recorder")
            // Clean up state
            self.currentAudioRecorder = nil
            self.recordTimer = nil
        }
    }

    /**********               Player               **********/

    func addPeriodicTimeObserver() {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: subscriptionDuration, preferredTimescale: timeScale)

        timeObserverToken = audioPlayer.addPeriodicTimeObserver(forInterval: time,
                                                                queue: .main) {_ in
            if (self.audioPlayer != nil) {
                self.sendEvent(withName: "rn-playback", body: [
                    "isMuted": self.audioPlayer.isMuted,
                    "currentPosition": self.audioPlayerItem.currentTime().seconds * 1000,
                    "duration": self.audioPlayerItem.asset.duration.seconds * 1000,
                    "isFinished": false,
                ])
            }
        }
    }

    func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            audioPlayer.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    @objc(startPlayer:httpHeaders:resolve:rejecter:)
    public func startPlayer(
        path: String,
        httpHeaders: [String: String],
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [
                AVAudioSession.CategoryOptions.defaultToSpeaker,
                AVAudioSession.CategoryOptions.allowBluetooth,
                AVAudioSession.CategoryOptions.mixWithOthers,
            ])
            try audioSession.setActive(true)
        } catch {
            reject("RNAudioPlayerRecorder", "Failed to play", nil)
        }
        updateAudioFileURL(path: path)
        audioPlayerAsset = AVURLAsset(url: audioFileURL!, options:["AVURLAssetHTTPHeaderFieldsKey": httpHeaders])
        audioPlayerItem = AVPlayerItem(asset: audioPlayerAsset!)

        if (audioPlayer == nil) {
            audioPlayer = AVPlayer(playerItem: audioPlayerItem)
        } else {
            audioPlayer.replaceCurrentItem(with: audioPlayerItem)
        }

        addPeriodicTimeObserver()
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: audioPlayer.currentItem)
        audioPlayer.play()
        resolve(audioFileURL?.absoluteString)
    }

    @objc
    public func playerDidFinishPlaying(notification: Notification) {
        if let playerItem = notification.object as? AVPlayerItem {
            let duration = playerItem.duration.seconds * 1000
            self.sendEvent(withName: "rn-playback", body: [
                "isMuted": self.audioPlayer?.isMuted as Any,
                "currentPosition": duration,
                "duration": duration,
                "isFinished": true,
            ])
        }
    }

    @objc(stopPlayer:rejecter:)
    public func stopPlayer(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioPlayer == nil) {
            return reject("RNAudioPlayerRecorder", "Player has already stopped.", nil)
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

        audioPlayer.seek(to: CMTime(seconds: time / 1000, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
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

    @objc(setPlaybackSpeed:resolve:rejecter:)
    public func setPlaybackSpeed(
        playbackSpeed: Float,
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (audioPlayer == nil) {
            return reject("RNAudioPlayerRecorder", "Player is null", nil)
        }

        audioPlayer.rate = playbackSpeed
        resolve("setPlaybackSpeed")
    }

    private func avFormat(fromString encoding: String) -> AudioFormatID? {
        switch encoding {
        case "lpcm":
            return kAudioFormatAppleIMA4
        case "ima4":
            return kAudioFormatAppleIMA4
        case "aac":
            return kAudioFormatMPEG4AAC
        case "MAC3":
            return kAudioFormatMACE3
        case "MAC6":
            return kAudioFormatMACE6
        case "ulaw":
            return kAudioFormatULaw
        case "alaw":
            return kAudioFormatALaw
        case "mp1":
            return kAudioFormatMPEGLayer1
        case "mp2":
            return kAudioFormatMPEGLayer2
        case "mp4":
            return kAudioFormatMPEG4AAC
        case "alac":
            return kAudioFormatAppleLossless
        case "amr":
            return kAudioFormatAMR
        case "flac":
            return kAudioFormatFLAC
        case "opus":
            return kAudioFormatOpus
        case "wav":
            return kAudioFormatLinearPCM
        default:
            return nil
        }
    }

    private func avMode(fromString mode: String) -> AVAudioSession.Mode? {
        switch mode {
        case "measurement":
            return .measurement
        case "gamechat":
            return .gameChat
        case "movieplayback":
            return .moviePlayback
        case "spokenaudio":
            return .spokenAudio
        case "videochat":
            return .videoChat
        case "videorecording":
            return .videoRecording
        case "voicechat":
            return .voiceChat
        case "voiceprompt":
            return .voicePrompt
        case "default":
            return .default
        default:
            return nil
        }
    }

    private func fileExtension(forAudioFormat format: AudioFormatID) -> String {
        switch format {
        case kAudioFormatOpus:
            return "ogg"
        case kAudioFormatLinearPCM:
            return "wav"
        case kAudioFormatAC3, kAudioFormat60958AC3:
            return "ac3"
        case kAudioFormatAppleIMA4:
            return "caf"
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4CELP, kAudioFormatMPEG4HVXC, kAudioFormatMPEG4TwinVQ, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_LD, kAudioFormatMPEG4AAC_ELD, kAudioFormatMPEG4AAC_ELD_SBR, kAudioFormatMPEG4AAC_ELD_V2, kAudioFormatMPEG4AAC_HE_V2, kAudioFormatMPEG4AAC_Spatial:
            return "m4a"
        case kAudioFormatMACE3, kAudioFormatMACE6:
            return "caf"
        case kAudioFormatULaw, kAudioFormatALaw:
            return "wav"
        case kAudioFormatQDesign, kAudioFormatQDesign2:
            return "mov"
        case kAudioFormatQUALCOMM:
            return "qcp"
        case kAudioFormatMPEGLayer1:
            return "mp1"
        case kAudioFormatMPEGLayer2:
            return "mp2"
        case kAudioFormatMPEGLayer3:
            return "mp3"
        case kAudioFormatMIDIStream:
            return "mid"
        case kAudioFormatAppleLossless:
            return "m4a"
        case kAudioFormatAMR:
            return "amr"
        case kAudioFormatAMR_WB:
            return "awb"
        case kAudioFormatAudible:
            return "aa"
        case kAudioFormatiLBC:
            return "ilbc"
        case kAudioFormatDVIIntelIMA, kAudioFormatMicrosoftGSM:
            return "wav"
        default:
            // Generic file extension for types that don't have a natural
            // file extension
            return "audio"
        }
    }

    /**********    Recorder Helpers (tracking recording duration)    **********/

    private func recordingDidStart() {
        self.accumulatedRecordingDuration = 0
        self.lastResumeTime = CACurrentMediaTime()
    }

    private func recordingDidPause() {
        guard let lastResumeTime else { return }

        self.accumulatedRecordingDuration += CACurrentMediaTime() - lastResumeTime
        self.lastResumeTime = nil
    }

    private func recordingDidResume() {
        self.lastResumeTime = CACurrentMediaTime()
    }

    private func recordingDidFinish() {
        self.accumulatedRecordingDuration = 0
        self.lastResumeTime = nil
    }

    /// Calculates the current total duration of the recording
    private func getCurrentRecordingDuration() -> Double {
        guard let lastResumeTime else { return accumulatedRecordingDuration }

        return accumulatedRecordingDuration + (CACurrentMediaTime() - lastResumeTime)
    }
}
