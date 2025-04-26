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
    
    // Independent timing system to overcome AVAudioRecorder timing issues
    var recordingStartTime: Date?
    var accumulatedRecordingTime: TimeInterval = 0
    var isRecordingActive: Bool = false

    // Recorder
    var audioRecorder: AVAudioRecorder!
    var audioSession: AVAudioSession!
    var recordTimer: Timer?
    var _meteringEnabled: Bool = false
    
    // Completion handler for recording finish
    var recordingFinishCompletion: ((Bool) -> Void)?

    // Player
    var pausedPlayTime: CMTime?
    var audioPlayerAsset: AVURLAsset!
    var audioPlayerItem: AVPlayerItem!
    var audioPlayer: AVPlayer!
    var timeObserverToken: Any?

    // Interruption handling state
    var interruptionResumeTimer: Timer? = nil
    var lastInterruptionTime: Date? = nil

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Clear any pending completion handlers to avoid retain cycles or memory leaks
        recordingFinishCompletion = nil
        
        // Clean up interruption timer
        interruptionResumeTimer?.invalidate()
        interruptionResumeTimer = nil
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
        
        // Create a consistent naming scheme based on the audio file URL and current segment index
        if let audioFileURL = self.audioFileURL {
            let originalFileName = audioFileURL.deletingPathExtension().lastPathComponent
            let fileExtension = audioFileURL.pathExtension
            let segmentIndex = self.audioSegmentURLs.count + 1
            let segmentFileName = "\(originalFileName)_segment\(segmentIndex).\(fileExtension)"
            return cachesDirectory.appendingPathComponent(segmentFileName)
        } else {
            // Fallback to UUID-based naming if audioFileURL is not set yet
            let uuid = UUID().uuidString
            return cachesDirectory.appendingPathComponent("segment_\(uuid).m4a")
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
            
            // Calculate current position using our independent timer
            let currentPosition: TimeInterval
            if isRecordingActive, let startTime = recordingStartTime {
                // Calculate elapsed time since recording started/resumed
                currentPosition = accumulatedRecordingTime + Date().timeIntervalSince(startTime)
            } else {
                currentPosition = accumulatedRecordingTime
            }

            let status = [
                "isRecording": audioRecorder.isRecording,
                "currentPosition": currentPosition * 1000, // Send time in milliseconds
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

            // Update our independent timing system
            if self.isRecordingActive, let startTime = self.recordingStartTime {
                self.accumulatedRecordingTime += Date().timeIntervalSince(startTime)
                self.recordingStartTime = nil
                self.isRecordingActive = false
            }
            
            // Clear any existing completion handler as pause doesn't trigger the finish recording delegate
            self.recordingFinishCompletion = nil
            
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
                
                // Update our independent timing system
                self.recordingStartTime = Date()
                self.isRecordingActive = true
                
                // When manually resuming, we continue with the same segment
                self.audioRecorder.record()

                if (self.recordTimer == nil) {
                    self.startRecorderTimer()
                }
                resolve("Recorder resumed!")
            } catch {
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
            return
        }

        // Cancel any pending interruption resume timer
        interruptionResumeTimer?.invalidate()
        interruptionResumeTimer = nil

        switch interruptionType {
        case AVAudioSession.InterruptionType.began.rawValue:
            // Record interruption time for rate limiting
            lastInterruptionTime = Date()
            
            // When interruption begins, save the current segment and update independent timing
            if audioRecorder != nil && audioRecorder.isRecording {
                
                // Update our independent timing
                if isRecordingActive, let startTime = recordingStartTime {
                    accumulatedRecordingTime += Date().timeIntervalSince(startTime)
                    recordingStartTime = nil
                    isRecordingActive = false
                }
                
                // Add current segment's duration to the cumulative time before stopping
                previousSegmentsDuration += audioRecorder.currentTime
                
                // Set up a completion handler for the stop operation
                recordingFinishCompletion = { [weak self] success in
                    guard let self = self else { return }
                    
                    // Save the current segment if recording was successful
                    if success, let currentURL = self.currentSegmentURL, FileManager.default.fileExists(atPath: currentURL.path) {
                        do {
                            // Check if the file has valid content before adding it
                            let attr = try FileManager.default.attributesOfItem(atPath: currentURL.path)
                            let fileSize = attr[FileAttributeKey.size] as! UInt64
                            
                            if fileSize > 0 {
                                self.audioSegmentURLs.append(currentURL)
                            } else {
                                try FileManager.default.removeItem(at: currentURL)
                            }
                        } catch {
                            print("Error checking segment file: \(error)")
                        }
                    }
                }
                
                // Stop recording on current segment
                audioRecorder.stop()
                // The completion handler will be called by audioRecorderDidFinishRecording
            }
            
            pauseRecorder { _ in } rejecter: { _, _, _ in }
            break
            
        case AVAudioSession.InterruptionType.ended.rawValue:
            guard let option = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { 
                return 
            }
            
            // Only attempt resume if we have the shouldResume flag and aren't already resuming
            if option == AVAudioSession.InterruptionOptions.shouldResume.rawValue && !isResumingFromInterruption {
                // Rate limit resumption attempts - don't try more than once every 2 seconds
                if let lastTime = lastInterruptionTime, Date().timeIntervalSince(lastTime) < 2.0 {
                    print("Ignoring rapid interruption sequence")
                    return
                }
                
                // Mark that we're in the process of resuming from interruption
                isResumingFromInterruption = true
                
                // Use a timer with a slightly longer delay (1.0 second) for better stability
                interruptionResumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    
                    do {
                        // Re-activate audio session explicitly
                        try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        
                        // Check if other audio is playing before proceeding
                        if self.audioSession.isOtherAudioPlaying {
                            print("Cannot resume recording: other audio is playing")
                            self.isResumingFromInterruption = false
                            return
                        }
                        
                        self.startNewSegment()
                        
                        // Resume recording and update independent timing
                        self.recordingStartTime = Date()
                        self.isRecordingActive = true
                        
                        self.resumeRecorder { _ in
                            self.isResumingFromInterruption = false
                        } rejecter: { code, message, error in
                            self.isResumingFromInterruption = false
                        }
                    } catch {
                        self.isResumingFromInterruption = false
                    }
                }
            }
            break
            
        default:
            break
        }
    }
    
    // Start a new recording segment with the same settings as the original
    func startNewSegment() {
        // Make sure any previous completion handler is cleared before starting a new segment
        recordingFinishCompletion = nil
        
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
        
        // Reset time tracking for a new recording
        previousSegmentsDuration = 0
        cumulativeRecordingTime = 0
        // Reset independent timer tracking
        accumulatedRecordingTime = 0
        recordingStartTime = nil
        isRecordingActive = false
        isResumingFromInterruption = false

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
                        reject("RNAudioPlayerRecorder", "Error occured during initiating recorder", nil)
                        return
                    }

                    // Start independent timing
                    self.recordingStartTime = Date()
                    self.isRecordingActive = true
                    startRecorderTimer()

                    // Return the final URL that will be produced after merging
                    resolve(audioFileURL?.absoluteString)
                    return
                }

                reject("RNAudioPlayerRecorder", "Error occured during initiating recorder", nil)
            } catch {
                reject("RNAudioPlayerRecorder", "Error occured during recording: \(error.localizedDescription)", nil)
            }
        }

        audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: avMode, options: [AVAudioSession.CategoryOptions.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetooth, AVAudioSession.CategoryOptions.mixWithOthers])
            try audioSession.setActive(true)

            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        startRecording()
                    } else {
                        reject("RNAudioPlayerRecorder", "Record permission not granted", nil)
                    }
                }
            }
        } catch {
            reject("RNAudioPlayerRecorder", "Failed to record", nil)
        }
    }

    @objc(stopRecorder:resolve:rejecter:)
    public func stopRecorder(
        returnSegments: Bool,
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if (recordTimer != nil) {
            recordTimer!.invalidate()
            recordTimer = nil
        }
        
        // Clean up any interruption timer
        interruptionResumeTimer?.invalidate()
        interruptionResumeTimer = nil
        isResumingFromInterruption = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                reject("RNAudioPlayerRecorder", "Recording context was deallocated", nil)
                return
            }
            
            if (self.audioRecorder == nil) {
                reject("RNAudioPlayerRecorder", "Failed to stop recorder. It is already nil.", nil)
                return
            }

            // Update our independent timing one final time
            if self.isRecordingActive, let startTime = self.recordingStartTime {
                self.accumulatedRecordingTime += Date().timeIntervalSince(startTime)
                self.recordingStartTime = nil
                self.isRecordingActive = false
            }
            
            // Add final segment duration to total before stopping
            self.previousSegmentsDuration += self.audioRecorder.currentTime
            self.cumulativeRecordingTime = self.previousSegmentsDuration
            
            // Set up completion handler before stopping the recorder
            self.recordingFinishCompletion = { [weak self] success in
                guard let self = self else {
                    reject("RNAudioPlayerRecorder", "Recording context was deallocated during finalization", nil)
                    return
                }
                
                if !success {
                    reject("RNAudioPlayerRecorder", "Recording failed to complete successfully", nil)
                    return
                }
                
                // Add the last segment to our array if it exists
                if let currentURL = self.currentSegmentURL, FileManager.default.fileExists(atPath: currentURL.path) {
                    self.audioSegmentURLs.append(currentURL)
                }
                
                // Filter out zero-length files that might have been created during interruptions
                self.audioSegmentURLs = self.audioSegmentURLs.filter { url in
                    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                          let fileSize = attrs[.size] as? UInt64 else {
                        return false
                    }
                    return fileSize > 0
                }
                
                // If we have no valid segments, return an error
                if self.audioSegmentURLs.isEmpty {
                    reject("RNAudioPlayerRecorder", "No valid audio was recorded", nil)
                    return
                }
                
                // If returnSegments is true, skip merging and return comma-separated paths
                if returnSegments {
                    // Since segments now have their final names already, just collect their paths
                    var finalPaths: [String] = []
                    
                    for segmentURL in self.audioSegmentURLs {
                        finalPaths.append(segmentURL.absoluteString)
                    }
                    
                    // Reset segment tracking arrays
                    self.audioSegmentURLs = []
                    self.currentSegmentURL = nil
                    
                    // Return comma-separated list of paths
                    let pathsString = finalPaths.joined(separator: ",")
                    resolve(pathsString)
                    return
                }
                
                // Original merging logic for backward compatibility
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
                        
                        // Clean up segment file
                        try FileManager.default.removeItem(at: singleSegment)
                        
                        // Reset segment tracking
                        self.audioSegmentURLs = []
                        self.currentSegmentURL = nil
                        resolve(self.audioFileURL?.absoluteString)
                    } catch {
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
                            resolve(self.audioFileURL?.absoluteString)
                        } else {
                            reject("RNAudioPlayerRecorder", "Failed to merge audio segments: \(error?.localizedDescription ?? "Unknown error")", nil)
                        }
                    })
                } else {
                    // No segments recorded (should not happen due to earlier check)
                    reject("RNAudioPlayerRecorder", "No audio was recorded", nil)
                }
            }
            
            // Now that the completion handler is set up, stop the recording
            self.audioRecorder.stop()
            // Note: We don't do any file operations here. They will happen in the completion handler
            // when audioRecorderDidFinishRecording is called.
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
                completion(false, error)
                return
            }
            
            // If the asset is empty (0 duration), skip it
            if assetDuration == .zero || CMTimeGetSeconds(assetDuration) < 0.1 {
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
                } else {
                    print("No audio track found in segment: \(segmentURL.lastPathComponent)")
                }
            } catch {
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
        
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(true, nil)
            case .failed, .cancelled:
                completion(false, exporter.error)
            default:
                completion(false, NSError(domain: "RNAudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(exporter.status.rawValue)"]))
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Failed to stop recorder")
        }
        
        // Call completion handler if set
        if let completion = recordingFinishCompletion {
            // Store the completion handler locally before clearing the property
            let localCompletion = completion
            // Reset the completion handler before calling it to avoid retain cycles
            recordingFinishCompletion = nil
            
            // Execute on main thread since UI updates might happen in the completion
            DispatchQueue.main.async {
                localCompletion(flag)
            }
        } else {
            // If there's no completion handler but recording failed, log it and send event
            if !flag {
                print("Recording failed with no completion handler set")
            }
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

    // Maintain backward compatibility with old method signature
    @objc(stopRecorderWithNoOptions:rejecter:)
    public func stopRecorderWithNoOptions(
        resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        // Call the new method with returnSegments = false for backward compatibility
        stopRecorder(returnSegments: false, resolve: resolve, rejecter: reject)
    }
}
