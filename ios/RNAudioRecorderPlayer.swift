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
    
    // Array to store segment file URLs
    var audioSegmentURLs: [URL] = []
    var currentSegmentURL: URL?
    
    // Track cumulative recording time across segments
    var cumulativeRecordingTime: TimeInterval = 0
    var previousSegmentsDuration: TimeInterval = 0
    var isResumingFromInterruption: Bool = false

    // Recorder
    var audioRecorder: AVAudioRecorder!
    var audioSession: AVAudioSession!
    var recordTimer: Timer?
    var _meteringEnabled: Bool = false

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
    
    // Generate a unique URL for a new segment
    func generateSegmentURL() -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let uuid = UUID().uuidString
        return cachesDirectory.appendingPathComponent("segment_\(uuid).m4a")
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
            
            // Calculate total recording time by adding current segment time to previous segments total
            let totalRecordingTime = previousSegmentsDuration + audioRecorder.currentTime

            let status = [
                "isRecording": audioRecorder.isRecording,
                "currentPosition": totalRecordingTime * 1000, // Send cumulative time in milliseconds
                "currentMetering": currentMetering,
            ] as [String : Any];

            sendEvent(withName: "rn-recordback", body: status)
        }
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

    @objc(pauseRecorder:rejecter:)
    public func pauseRecorder(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        recordTimer?.invalidate()
        recordTimer = nil;

        DispatchQueue.main.async {
            if (self.audioRecorder == nil) {
                return reject("RNAudioPlayerRecorder", "Recorder is not recording", nil)
            }

            // Store the current time when pausing
            if self.audioRecorder.isRecording {
                // We don't add to previousSegmentsDuration here because we're not creating a new segment
                // We'll continue recording to the same segment when resumed
            }
            
            self.audioRecorder.pause()
            resolve("Recorder paused!")
        }
    }

    @objc(resumeRecorder:rejecter:)
    public func resumeRecorder(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        DispatchQueue.main.async {
            if (self.audioRecorder == nil) {
                return reject("RNAudioPlayerRecorder", "Recorder is nil", nil)
            }

            do {
                // Always try to reactivate the audio session before resuming
                try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // When manually resuming, we continue with the same segment
                // No need to update previousSegmentsDuration as we're continuing the same segment
                self.audioRecorder.record()

                if (self.recordTimer == nil) {
                    self.startRecorderTimer()
                }
                resolve("Recorder resumed!")
            } catch {
                print("Failed to resume recorder: \(error)")
                reject("RNAudioPlayerRecorder", "Failed to resume recorder: \(error.localizedDescription)", nil)
            }
        }
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
        guard let userInfo = notification.userInfo,
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt else {
            print("Audio Session Interruption: No userInfo or interruptionType")
            return
        }

        switch interruptionType {
        case AVAudioSession.InterruptionType.began.rawValue:
            print("Audio Session Interruption: BEGAN")
            
            // When interruption begins, save the current segment
            if audioRecorder != nil && audioRecorder.isRecording {
                print("Audio Session Interruption: Saving recording state before interruption")
                
                // Add current segment's duration to the cumulative time before stopping
                previousSegmentsDuration += audioRecorder.currentTime
                
                // Stop recording on current segment
                audioRecorder.stop()
                
                // Save the current segment
                if let currentURL = currentSegmentURL, FileManager.default.fileExists(atPath: currentURL.path) {
                    do {
                        // Check if the file has valid content before adding it
                        let attr = try FileManager.default.attributesOfItem(atPath: currentURL.path)
                        let fileSize = attr[FileAttributeKey.size] as! UInt64
                        
                        if fileSize > 0 {
                            audioSegmentURLs.append(currentURL)
                            print("Added segment at interruption: \(currentURL.lastPathComponent), size: \(fileSize) bytes")
                        } else {
                            print("Skipping empty segment file: \(currentURL.lastPathComponent)")
                            try FileManager.default.removeItem(at: currentURL)
                        }
                    } catch {
                        print("Error checking segment file: \(error)")
                    }
                }
            }
            
            pauseRecorder { _ in } rejecter: { _, _, _ in }
            break
            
        case AVAudioSession.InterruptionType.ended.rawValue:
            print("Audio Session Interruption: ENDED")
            guard let option = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { 
                print("Audio Session Interruption: No option provided")
                return 
            }
            
            if option == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
                print("Audio Session Interruption: System suggests we should resume")
                
                // Mark that we're in the process of resuming from interruption
                isResumingFromInterruption = true
                
                // Delay resumption slightly to allow system to stabilize
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        // Re-activate audio session explicitly
                        print("Audio Session Interruption: Reactivating audio session")
                        try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        
                        // Check if other audio is playing before proceeding
                        if self.audioSession.isOtherAudioPlaying {
                            print("Audio Session Interruption: Other audio is playing, can't resume safely")
                            self.isResumingFromInterruption = false
                            return
                        }
                        
                        print("Audio Session Interruption: Starting new segment")
                        self.startNewSegment()
                        
                        print("Audio Session Interruption: Resuming recorder")
                        self.resumeRecorder { _ in
                            print("Audio Session Interruption: Resume succeeded")
                            self.isResumingFromInterruption = false
                        } rejecter: { code, message, error in
                            print("Audio Session Interruption: Resume failed - \(message ?? "unknown error")")
                            self.isResumingFromInterruption = false
                        }
                    } catch {
                        print("Audio Session Interruption: Failed to reactivate audio session - \(error)")
                        self.isResumingFromInterruption = false
                    }
                }
            } else {
                print("Audio Session Interruption: System does not suggest resuming")
            }
            break
            
        default:
            print("Audio Session Interruption: Unknown interruption type: \(interruptionType)")
            break
        }
    }
    
    // Start a new recording segment with the same settings as the original
    func startNewSegment() {
        // Create a new segment file URL
        currentSegmentURL = generateSegmentURL()
        
        // If we have existing recorder settings, use them for the new segment
        if audioRecorder != nil {
            let settings = audioRecorder.settings
            do {
                // No need to check if session is active, just check if other audio is playing
                if !audioSession.isOtherAudioPlaying {
                    audioRecorder = try AVAudioRecorder(url: currentSegmentURL!, settings: settings)
                    audioRecorder.prepareToRecord()
                    audioRecorder.delegate = self
                    audioRecorder.isMeteringEnabled = _meteringEnabled
                    print("Created new segment recorder with cumulative time: \(previousSegmentsDuration) seconds, URL: \(currentSegmentURL!.lastPathComponent)")
                } else {
                    print("Cannot start new segment: other audio is playing")
                }
            } catch {
                print("Failed to create new segment recorder: \(error)")
            }
        } else {
            print("Cannot start new segment: no existing recorder settings")
        }
    }

    /**********               Player               **********/

    @objc(startRecorder:audioSets:meteringEnabled:resolve:reject:)
    func startRecorder(path: String,  audioSets: [String: Any], meteringEnabled: Bool, resolve: @escaping RCTPromiseResolveBlock,
       rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {

        _meteringEnabled = meteringEnabled;
        
        // Reset segment array when starting a new recording
        audioSegmentURLs = []
        currentSegmentURL = generateSegmentURL()
        
        // Reset cumulative time tracking for a new recording
        previousSegmentsDuration = 0
        cumulativeRecordingTime = 0
        isResumingFromInterruption = false
        
        print("Starting recording with first segment: \(currentSegmentURL?.lastPathComponent ?? "nil")")

        let encoding = audioSets["AVFormatIDKeyIOS"] as? String
        let mode = audioSets["AVModeIOS"] as? String
        let avLPCMBitDepth = audioSets["AVLinearPCMBitDepthKeyIOS"] as? Int
        let avLPCMIsBigEndian = audioSets["AVLinearPCMIsBigEndianKeyIOS"] as? Bool
        let avLPCMIsFloatKey = audioSets["AVLinearPCMIsFloatKeyIOS"] as? Bool
        let avLPCMIsNonInterleaved = audioSets["AVLinearPCMIsNonInterleavedIOS"] as? Bool

        var avMode: AVAudioSession.Mode = AVAudioSession.Mode.default
        var sampleRate = audioSets["AVSampleRateKeyIOS"] as? Int
        var numberOfChannel = audioSets["AVNumberOfChannelsKeyIOS"] as? Int
        var audioQuality = audioSets["AVEncoderAudioQualityKeyIOS"] as? Int
        var bitRate = audioSets["AVEncoderBitRateKeyIOS"] as? Int

        if (sampleRate == nil) {
            sampleRate = 44100;
        }

        guard let avFormat: AudioFormatID = avFormat(fromString: encoding) else {
            return reject("RNAudioPlayerRecorder", "Audio format not available", nil)
        }

        // Set the final output URL (this will be used when merging segments)
        if (path == "DEFAULT") {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileExt = fileExtension(forAudioFormat: avFormat)
            audioFileURL = cachesDirectory.appendingPathComponent("sound." + fileExt)
        } else {
            setAudioFileURL(path: path)
        }

        if (mode == "measurement") {
            avMode = AVAudioSession.Mode.measurement
        } else if (mode == "gamechat") {
            avMode = AVAudioSession.Mode.gameChat
        } else if (mode == "movieplayback") {
            avMode = AVAudioSession.Mode.moviePlayback
        } else if (mode == "spokenaudio") {
            avMode = AVAudioSession.Mode.spokenAudio
        } else if (mode == "videochat") {
            avMode = AVAudioSession.Mode.videoChat
        } else if (mode == "videorecording") {
            avMode = AVAudioSession.Mode.videoRecording
        } else if (mode == "voicechat") {
            avMode = AVAudioSession.Mode.voiceChat
        } else if (mode == "voiceprompt") {
            if #available(iOS 12.0, *) {
                avMode = AVAudioSession.Mode.voicePrompt
            } else {
                // Fallback on earlier versions
            }
        }


        if (numberOfChannel == nil) {
            numberOfChannel = 2
        }

        if (audioQuality == nil) {
            audioQuality = AVAudioQuality.medium.rawValue
        }

        if (bitRate == nil) {
            bitRate = 128000
        }

        func startRecording() {
            let settings = [
                AVSampleRateKey: sampleRate!,
                AVFormatIDKey: avFormat,
                AVNumberOfChannelsKey: numberOfChannel!,
                AVEncoderAudioQualityKey: audioQuality!,
                AVLinearPCMBitDepthKey: avLPCMBitDepth ?? AVLinearPCMBitDepthKey.count,
                AVLinearPCMIsBigEndianKey: avLPCMIsBigEndian ?? true,
                AVLinearPCMIsFloatKey: avLPCMIsFloatKey ?? false,
                AVLinearPCMIsNonInterleaved: avLPCMIsNonInterleaved ?? false,
                AVEncoderBitRateKey: bitRate!
            ] as [String : Any]

            do {
                audioRecorder = try AVAudioRecorder(url: currentSegmentURL!, settings: settings)

                if (audioRecorder != nil) {
                    audioRecorder.prepareToRecord()
                    audioRecorder.delegate = self
                    audioRecorder.isMeteringEnabled = _meteringEnabled
                    let isRecordStarted = audioRecorder.record()

                    if !isRecordStarted {
                        print("Failed to start recording")
                        reject("RNAudioPlayerRecorder", "Error occured during initiating recorder", nil)
                        return
                    }

                    print("Recording started successfully")
                    startRecorderTimer()

                    // Return the final URL that will be produced after merging
                    resolve(audioFileURL?.absoluteString)
                    return
                }

                print("Recorder is nil after initialization")
                reject("RNAudioPlayerRecorder", "Error occured during initiating recorder", nil)
            } catch {
                print("Error starting recorder: \(error)")
                reject("RNAudioPlayerRecorder", "Error occured during recording: \(error.localizedDescription)", nil)
            }
        }

        audioSession = AVAudioSession.sharedInstance()

        do {
            print("Configuring audio session for recording")
            try audioSession.setCategory(.playAndRecord, mode: avMode, options: [AVAudioSession.CategoryOptions.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetooth, AVAudioSession.CategoryOptions.mixWithOthers])
            try audioSession.setActive(true)

            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Record permission granted, starting recording")
                        startRecording()
                    } else {
                        print("Record permission not granted")
                        reject("RNAudioPlayerRecorder", "Record permission not granted", nil)
                    }
                }
            }
        } catch {
            print("Failed to configure audio session: \(error)")
            reject("RNAudioPlayerRecorder", "Failed to record", nil)
        }
    }

    @objc(stopRecorder:rejecter:)
    public func stopRecorder(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (recordTimer != nil) {
            recordTimer!.invalidate()
            recordTimer = nil
        }

        DispatchQueue.main.async {
            if (self.audioRecorder == nil) {
                reject("RNAudioPlayerRecorder", "Failed to stop recorder. It is already nil.", nil)
                return
            }

            // Add final segment duration to total before stopping
            self.previousSegmentsDuration += self.audioRecorder.currentTime
            self.cumulativeRecordingTime = self.previousSegmentsDuration
            
            // Stop the current recording
            self.audioRecorder.stop()
            
            // Add the last segment to our array if it exists
            if let currentURL = self.currentSegmentURL, FileManager.default.fileExists(atPath: currentURL.path) {
                self.audioSegmentURLs.append(currentURL)
                print("Added final segment: \(currentURL.lastPathComponent)")
            }
            
            // Filter out zero-length files that might have been created during interruptions
            self.audioSegmentURLs = self.audioSegmentURLs.filter { url in
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let fileSize = attrs[.size] as? UInt64 else {
                    return false
                }
                return fileSize > 0
            }
            
            print("Total segments to process: \(self.audioSegmentURLs.count)")
            
            // If we have no valid segments, return an error
            if self.audioSegmentURLs.isEmpty {
                reject("RNAudioPlayerRecorder", "No valid audio was recorded", nil)
                return
            }
            
            // If we only have one segment, just use that file
            if self.audioSegmentURLs.count == 1, let singleSegment = self.audioSegmentURLs.first {
                do {
                    // Make sure the destination directory exists
                    try FileManager.default.createDirectory(at: self.audioFileURL!.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    
                    // Remove any existing file at the destination
                    if FileManager.default.fileExists(atPath: self.audioFileURL!.path) {
                        try FileManager.default.removeItem(at: self.audioFileURL!)
                    }
                    
                    // Copy the segment to the final destination
                    try FileManager.default.copyItem(at: singleSegment, to: self.audioFileURL!)
                    print("Copied single segment to final destination")
                    
                    // Clean up segment file
                    try FileManager.default.removeItem(at: singleSegment)
                    
                    // Reset segment tracking
                    self.audioSegmentURLs = []
                    self.currentSegmentURL = nil
                    
                    resolve(self.audioFileURL?.absoluteString)
                } catch {
                    print("Error finalizing single segment recording: \(error)")
                    reject("RNAudioPlayerRecorder", "Failed to finalize recording: \(error.localizedDescription)", nil)
                    
                    // Clean up segment
                    try? FileManager.default.removeItem(at: singleSegment)
                    self.audioSegmentURLs = []
                    self.currentSegmentURL = nil
                }
            } 
            // If we have multiple segments, we need to stitch them together
            else if self.audioSegmentURLs.count > 1 {
                // Make sure the destination directory exists
                do {
                    try FileManager.default.createDirectory(at: self.audioFileURL!.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    
                    // Remove any existing file at the destination
                    if FileManager.default.fileExists(atPath: self.audioFileURL!.path) {
                        try FileManager.default.removeItem(at: self.audioFileURL!)
                    }
                } catch {
                    print("Error preparing output directory: \(error)")
                }
                
                self.mergeAudioSegments(completion: { success, error in
                    // Clean up temp files regardless of success or failure
                    for url in self.audioSegmentURLs {
                        try? FileManager.default.removeItem(at: url)
                    }
                    
                    // Reset segment tracking
                    self.audioSegmentURLs = []
                    self.currentSegmentURL = nil
                    
                    if success {
                        print("Successfully merged \(self.audioSegmentURLs.count) segments")
                        resolve(self.audioFileURL?.absoluteString)
                    } else {
                        print("Failed to merge audio segments: \(error?.localizedDescription ?? "Unknown error")")
                        reject("RNAudioPlayerRecorder", "Failed to merge audio segments: \(error?.localizedDescription ?? "Unknown error")", nil)
                    }
                })
            } else {
                // No segments recorded (should not happen due to earlier check)
                reject("RNAudioPlayerRecorder", "No audio was recorded", nil)
            }
        }
    }
    
    // Merge multiple audio segments into a single file
    func mergeAudioSegments(completion: @escaping (Bool, Error?) -> Void) {
        // Create a composition of all audio segments
        let composition = AVMutableComposition()
        
        // Create audio track
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            completion(false, NSError(domain: "RNAudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"]))
            return
        }
        
        // Add each segment to the composition
        var insertTime = CMTime.zero
        var segmentsAdded = 0
        
        for segmentURL in audioSegmentURLs {
            let asset = AVURLAsset(url: segmentURL)
            
            // Wait for the asset to load its duration
            let semaphore = DispatchSemaphore(value: 0)
            var assetDuration: CMTime = .zero
            var loadError: Error?
            
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                var error: NSError? = nil
                let status = asset.statusOfValue(forKey: "duration", error: &error)
                
                switch status {
                case .loaded:
                    assetDuration = asset.duration
                case .failed, .cancelled, .unknown:
                    loadError = error
                default:
                    break
                }
                
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 5.0)
            
            if let error = loadError {
                print("Error loading asset duration: \(error)")
                completion(false, error)
                return
            }
            
            // If the asset is empty (0 duration), skip it
            if assetDuration == .zero || CMTimeGetSeconds(assetDuration) < 0.1 {
                print("Skipping zero-length segment: \(segmentURL.lastPathComponent)")
                continue
            }
            
            do {
                if let assetTrack = asset.tracks(withMediaType: .audio).first {
                    try compositionTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: assetDuration),
                        of: assetTrack,
                        at: insertTime
                    )
                    
                    insertTime = CMTimeAdd(insertTime, assetDuration)
                    segmentsAdded += 1
                    print("Added segment to composition: \(segmentURL.lastPathComponent), duration: \(CMTimeGetSeconds(assetDuration))")
                } else {
                    print("No audio track found in segment: \(segmentURL.lastPathComponent)")
                }
            } catch {
                print("Error inserting segment into composition: \(error)")
                completion(false, error)
                return
            }
        }
        
        // If no segments were added, return an error
        if segmentsAdded == 0 {
            completion(false, NSError(domain: "RNAudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid audio segments to merge"]))
            return
        }
        
        // Export the composition to the final file
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A)
        else {
            completion(false, NSError(domain: "RNAudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
            return
        }
        
        exporter.outputURL = audioFileURL
        exporter.outputFileType = .m4a
        print("Starting export to: \(audioFileURL?.lastPathComponent ?? "nil")")
        
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                print("Export completed successfully")
                completion(true, nil)
            case .failed, .cancelled:
                print("Export failed with error: \(exporter.error?.localizedDescription ?? "Unknown")")
                completion(false, exporter.error)
            default:
                print("Export ended with status: \(exporter.status.rawValue)")
                completion(false, NSError(domain: "RNAudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(exporter.status.rawValue)"]))
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Failed to stop recorder")
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
        audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [AVAudioSession.CategoryOptions.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            reject("RNAudioPlayerRecorder", "Failed to play", nil)
        }

        setAudioFileURL(path: path)
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

    private func avFormat(fromString encoding: String?) -> AudioFormatID? {
        if (encoding == nil) {
            return kAudioFormatAppleLossless
        } else {
            if (encoding == "lpcm") {
                return kAudioFormatAppleIMA4
            } else if (encoding == "ima4") {
                return kAudioFormatAppleIMA4
            } else if (encoding == "aac") {
                return kAudioFormatMPEG4AAC
            } else if (encoding == "MAC3") {
                return kAudioFormatMACE3
            } else if (encoding == "MAC6") {
                return kAudioFormatMACE6
            } else if (encoding == "ulaw") {
                return kAudioFormatULaw
            } else if (encoding == "alaw") {
                return kAudioFormatALaw
            } else if (encoding == "mp1") {
                return kAudioFormatMPEGLayer1
            } else if (encoding == "mp2") {
                return kAudioFormatMPEGLayer2
            } else if (encoding == "mp4") {
                return kAudioFormatMPEG4AAC
            } else if (encoding == "alac") {
                return kAudioFormatAppleLossless
            } else if (encoding == "amr") {
                return kAudioFormatAMR
            } else if (encoding == "flac") {
                if #available(iOS 11.0, *) {
                    return kAudioFormatFLAC
                }
            } else if (encoding == "opus") {
                return kAudioFormatOpus
            } else if (encoding == "wav") {
                return kAudioFormatLinearPCM
            }
        }
        return nil;
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
}
