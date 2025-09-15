import Foundation
import AVFoundation
import NitroModules

final class HybridSound: HybridSoundSpec_base, HybridSoundSpec_protocol {
    // Small delay to ensure the audio session is fully active before recording starts
    private let audioSessionActivationDelay: TimeInterval = 0.1
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?

    private var recordTimer: Timer?
    private var playTimer: Timer?

    private var recordBackListener: ((RecordBackType) -> Void)?
    private var playBackListener: ((PlayBackType) -> Void)?
    private var playbackEndListener: ((PlaybackEndType) -> Void)?

    private var subscriptionDuration: TimeInterval = 0.06
    private var playbackRate: Double = 1.0 // default 1x
    private var recordingSession: AVAudioSession?

    // MARK: - Recording Methods

    public func startRecorder(uri: String?, audioSets: AudioSet?, meteringEnabled: Bool?) throws -> Promise<String> {
        let promise = Promise<String>()

        // Return immediately to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                promise.reject(withError: RuntimeError.error(withMessage: "Self is nil"))
                return
            }

            do {
                // Setup audio session in background
                self.recordingSession = AVAudioSession.sharedInstance()

                // Apply AVModeIOS if provided
                let sessionMode = audioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default

                try self.recordingSession?.setCategory(.playAndRecord,
                                                     mode: sessionMode,
                                                     options: [.defaultToSpeaker, .allowBluetooth])
                try self.recordingSession?.setActive(true)

                print("🎙️ Audio session set up successfully")

                // Request permission if needed
                self.recordingSession?.requestRecordPermission { [weak self] allowed in
                    guard let self = self else { return }

                    if allowed {
                        // Continue in background
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.setupAndStartRecording(uri: uri, audioSets: audioSets, meteringEnabled: meteringEnabled, promise: promise)
                        }
                    } else {
                        promise.reject(withError: RuntimeError.error(withMessage: "Recording permission denied. Please enable microphone access in Settings."))
                    }
                }
            } catch {
                print("🎙️ Audio session setup failed: \(error)")
                promise.reject(withError: RuntimeError.error(withMessage: "Audio session setup failed: \(error.localizedDescription)"))
            }
        }

        return promise
    }

    private func setupAndStartRecording(uri: String?, audioSets: AudioSet?, meteringEnabled: Bool?, promise: Promise<String>) {
        do {
            print("🎙️ Setting up recording...")

            // Setup recording URL
            let fileURL: URL
            if let uri = uri {
                fileURL = URL(fileURLWithPath: uri)
                print("🎙️ Using provided URI: \(uri)")
            } else {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "sound_\(Date().timeIntervalSince1970).m4a"
                fileURL = documentsPath.appendingPathComponent(fileName)
                print("🎙️ Generated file path: \(fileURL.path)")
            }

            // Check if directory exists and is writable
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                print("🎙️ Directory doesn't exist: \(directory.path)")
                throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Directory doesn't exist"])
            }

            if !FileManager.default.isWritableFile(atPath: directory.path) {
                print("🎙️ Directory is not writable: \(directory.path)")
                throw NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Directory is not writable"])
                throw NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Directory is not writable"])
                throw NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Directory is not writable"])
            }

            print("🎙️ Recording to: \(fileURL.path)")
            print("🎙️ Directory exists and is writable: \(directory.path)")

            // Setup audio settings
            let settings = self.getAudioSettings(audioSets: audioSets)
            print("🎙️ Audio settings: \(settings)")

            // Create recorder
            print("🎙️ Creating AVAudioRecorder...")
            self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            print("🎙️ AVAudioRecorder created successfully")

            self.audioRecorder?.isMeteringEnabled = meteringEnabled ?? false
            print("🎙️ Metering enabled: \(meteringEnabled ?? false)")

            print("🎙️ Preparing to record...")
            let prepared = self.audioRecorder?.prepareToRecord() ?? false
            print("🎙️ Recorder prepared: \(prepared)")

            if !prepared {
                throw NSError(domain: "AudioRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare recorder"])
            }

            // Start recording on main queue
            DispatchQueue.main.async {
                print("🎙️ Starting recording...")

                // Ensure audio session is active before recording
                do {
                    try self.recordingSession?.setActive(true)
                    print("🎙️ Audio session activated")
                } catch let error {
                    print("🎙️ Error: Audio session activation failed: \(error)")
                    promise.reject(withError: RuntimeError.error(withMessage: "Failed to activate audio session: \(error.localizedDescription)"))
                    return
                }

                // Small delay to ensure session is fully active
                DispatchQueue.main.asyncAfter(deadline: .now() + self.audioSessionActivationDelay) {
                    // Check if audio session is still active
                    let audioSession = AVAudioSession.sharedInstance()
                    if !audioSession.isOtherAudioPlaying {
                        print("🎙️ No other audio playing, proceeding with recording")
                    } else {
                        print("🎙️ Warning: Other audio is playing")
                    }

                    // Try to record with retry mechanism
                    var recordAttempts = 0
                    let maxAttempts = 3

                    func attemptRecording() {
                        recordAttempts += 1
                        print("🎙️ Recording attempt \(recordAttempts)/\(maxAttempts)")

                        func configureAndStartRecording() {
                            // Check if session is still valid and not hijacked right before recording
                            let currentCategory = audioSession.category
                            let currentMode = audioSession.mode

                            // Check if session is corrupted (empty category/mode)
                            if currentCategory.rawValue.isEmpty || currentMode.rawValue.isEmpty {
                                print("🎙️ ⚠️ Audio session is corrupted, attempting to recover...")
                                // Try to recover the session
                                do {
                                    // Reuse existing session instance (singleton)
                                    let sessionMode = audioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default
                                    try audioSession.setCategory(.playAndRecord, mode: sessionMode, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                                    try audioSession.setActive(true, options: [])
                                    print("🎙️ ✅ Audio session recovered successfully")
                                } catch {
                                    print("🎙️ ❌ Failed to recover audio session: \(error)")
                                    promise.reject(withError: RuntimeError.error(withMessage: "Failed to recover corrupted audio session: \(error.localizedDescription)"))
                                    return
                                }
                            } else if currentCategory != .playAndRecord {
                                print("🎙️ ⚠️ Session still hijacked before recording attempt: \(currentCategory)")
                                // Force immediate session takeover
                                do {
                                    let sessionMode = audioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default
                                    try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                                    try audioSession.setCategory(.playAndRecord, mode: sessionMode, options: [.defaultToSpeaker, .allowBluetooth])
                                    try audioSession.setActive(true)
                                    print("🎙️ ✅ Forced immediate session takeover")
                                } catch {
                                    print("🎙️ ❌ Failed immediate session takeover: \(error)")
                                    promise.reject(withError: RuntimeError.error(withMessage: "Failed to recover hijacked audio session: \(error.localizedDescription)"))
                                    return
                                }
                            }

                            // If session was changed, recreate the recorder to ensure compatibility
                            if currentCategory != .playAndRecord || recordAttempts > 1 {
                                print("🎙️ ⚠️ Session was changed, recreating recorder for compatibility...")
                                do {
                                    // Recreate the recorder with current session state
                                    let settings = self.getAudioSettings(audioSets: audioSets)
                                    self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                                    self.audioRecorder?.isMeteringEnabled = meteringEnabled ?? false
                                    let prepared = self.audioRecorder?.prepareToRecord() ?? false
                                    print("🎙️ ✅ Recorder recreated and prepared: \(prepared)")
                                    if !prepared {
                                        throw NSError(domain: "AudioRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare recreated recorder"])
                                    }
                                } catch {
                                    print("🎙️ ❌ Failed to recreate recorder: \(error)")
                                    promise.reject(withError: RuntimeError.error(withMessage: "Failed to recreate recorder: \(error.localizedDescription)"))
                                    return
                                }
                            }

                            let started = self.audioRecorder?.record() ?? false
                            print("🎙️ Recording started: \(started)")

                            if started {
                                self.startRecordTimer()
                                promise.resolve(withResult: fileURL.absoluteString)
                            } else if recordAttempts < maxAttempts {
                                print("🎙️ Recording attempt \(recordAttempts) failed, retrying in 0.3s...")

                                // Try to fully reset audio session before retry
                                do {
                                    try audioSession.setActive(false)

                                    // Re-set the category to ensure it's correct
                                    let sessionMode = audioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default
                                    try audioSession.setCategory(.playAndRecord,
                                                               mode: sessionMode,
                                                               options: [.defaultToSpeaker, .allowBluetooth])
                                    try audioSession.setActive(true)
                                    print("🎙️ Audio session fully reset for retry")
                                } catch {
                                    print("🎙️ Warning: Could not reset session: \(error)")
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    attemptRecording()
                                }
                            } else {
                                // All attempts failed, provide detailed error info
                                let isRecording = self.audioRecorder?.isRecording ?? false
                                let sessionCategory = audioSession.category
                                let sessionMode = audioSession.mode
                                let otherAudioPlaying = audioSession.isOtherAudioPlaying

                                print("🎙️ All recording attempts failed")
                                print("🎙️ Recorder state - isRecording: \(isRecording)")
                                print("🎙️ Audio session - category: \(sessionCategory), mode: \(sessionMode)")
                                print("🎙️ Audio session - other audio playing: \(otherAudioPlaying)")

                                var errorMessage = "Failed to start recording after \(maxAttempts) attempts."
                                if sessionCategory != .playAndRecord {
                                    errorMessage += " Audio session was hijacked by another app (category: \(sessionCategory.rawValue)). Try closing other media apps."
                                } else if otherAudioPlaying {
                                    errorMessage += " Other audio is currently playing. Please stop other audio apps and try again."
                                } else {
                                    errorMessage += " Please check microphone permissions and ensure no other apps are using the microphone."
                                }

                                promise.reject(withError: RuntimeError.error(withMessage: errorMessage))
                            }
                        }

                        // Non-blocking audio session configuration
                        func configureAudioSession(completion: @escaping () -> Void) {
                            let currentCategory = audioSession.category
                            let currentMode = audioSession.mode

                            // Check if we need to reconfigure
                            if currentCategory != .playAndRecord || recordAttempts > 1 {
                                if currentCategory != .playAndRecord {
                                    print("🎙️ ⚠️ Audio session category was changed to: \(currentCategory)")
                                    print("🎙️ ⚠️ Audio session mode was changed to: \(currentMode)")
                                }
                                print("🎙️ Forcing correct category and mode for recording (attempt \(recordAttempts))...")

                                // Step 1: Deactivate current session
                                do {
                                    try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                                } catch {
                                    print("🎙️ Warning: Could not deactivate session: \(error)")
                                }

                                // Step 2: Configure with mixing after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    do {
                                        let sessionMode = audioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default
                                        try audioSession.setCategory(.playAndRecord,
                                                                   mode: sessionMode,
                                                                   options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                                        try audioSession.setActive(true, options: [])
                                    } catch {
                                        print("🎙️ Warning: Could not set mixing category: \(error)")
                                    }

                                    // Step 3: Configure exclusive access after another delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        do {
                                            let sessionMode = audioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default
                                            try audioSession.setCategory(.playAndRecord,
                                                                       mode: sessionMode,
                                                                       options: [.defaultToSpeaker, .allowBluetooth])
                                            try audioSession.setActive(true)
                                            print("🎙️ Audio session corrected and exclusively activated")
                                        } catch let error as NSError {
                                            print("🎙️ Error setting exclusive category: \(error)")

                                            // Handle OSStatus -50 error
                                            if error.code == -50 {
                                                print("🎙️ Attempting simple activation due to param error...")
                                                do {
                                                    try audioSession.setCategory(.playAndRecord)
                                                    try audioSession.setActive(true)
                                                } catch {
                                                    print("🎙️ Simple activation also failed: \(error)")
                                                }
                                            }
                                        }

                                        // Step 4: Allow system to settle then start recording
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            completion()
                                        }
                                    }
                                }
                            } else {
                                // No reconfiguration needed, proceed immediately
                                completion()
                            }
                        }

                        // Start the configuration and recording sequence
                        configureAudioSession {
                            configureAndStartRecording()
                        }
                    }

                    attemptRecording()
                }
            }

        } catch {
            print("🎙️ Recording setup failed: \(error)")
            print("🎙️ Error details: \(error)")
            if let nsError = error as NSError? {
                print("🎙️ Error domain: \(nsError.domain)")
                print("🎙️ Error code: \(nsError.code)")
                print("🎙️ Error userInfo: \(nsError.userInfo)")
            }
            promise.reject(withError: RuntimeError.error(withMessage: "Recording setup failed: \(error.localizedDescription)"))
        }
    }

    public func pauseRecorder() throws -> Promise<String> {
        let promise = Promise<String>()

        if let recorder = self.audioRecorder, recorder.isRecording {
            recorder.pause()
            self.stopRecordTimer()
            promise.resolve(withResult: "Recorder paused")
        } else {
            promise.reject(withError: RuntimeError.error(withMessage: "Recorder is not recording"))
        }

        return promise
    }

    public func resumeRecorder() throws -> Promise<String> {
        let promise = Promise<String>()

        if let recorder = self.audioRecorder, !recorder.isRecording {
            recorder.record()
            DispatchQueue.main.async {
                self.startRecordTimer()
            }
            promise.resolve(withResult: "Recorder resumed")
        } else {
            promise.reject(withError: RuntimeError.error(withMessage: "Recorder is already recording"))
        }

        return promise
    }

    public func stopRecorder() throws -> Promise<String> {
        let promise = Promise<String>()

        // Return immediately and process in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                promise.reject(withError: RuntimeError.error(withMessage: "Self is nil"))
                return
            }

            if let recorder = self.audioRecorder {
                let url = recorder.url.absoluteString

                // Stop recorder on main queue
                DispatchQueue.main.async {
                    recorder.stop()
                    self.stopRecordTimer()

                    // Continue cleanup in background
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.audioRecorder = nil

                        // Deactivate audio session
                        try? self.recordingSession?.setActive(false)
                        self.recordingSession = nil

                        promise.resolve(withResult: url)
                    }
                }
            } else {
                promise.reject(withError: RuntimeError.error(withMessage: "No recorder instance"))
            }
        }

        return promise
    }

    // MARK: - Playback Methods

    public func startPlayer(uri: String?, httpHeaders: Dictionary<String, String>?) throws -> Promise<String> {
        let promise = Promise<String>()

        // Return immediately and process in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                promise.reject(withError: RuntimeError.error(withMessage: "Self is nil"))
                return
            }

            do {
                print("🎵 Starting player for URI: \(uri ?? "nil")")

                // Setup audio session
                let audioSession = AVAudioSession.sharedInstance()
                print("🎵 Setting up audio session for playback...")
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                print("🎵 Audio session setup complete")

                if let uri = uri, !uri.isEmpty {
                    print("🎵 URI provided: \(uri)")

                    if uri.hasPrefix("http") {
                        print("🎵 Detected remote URL, using engine player")
                        // Handle remote URL
                        self.setupEnginePlayer(url: uri, httpHeaders: httpHeaders, promise: promise)
                    } else {
                        print("🎵 Detected local file")
                        // Handle local file - check if file exists
                        let url: URL
                        if uri.hasPrefix("file://") {
                            print("🎵 URI has file:// prefix")
                            // Handle file:// URLs
                            url = URL(string: uri)!
                            print("🎵 Created URL from string: \(url)")
                        } else {
                            print("🎵 URI is plain path")
                            // Handle plain file paths
                            url = URL(fileURLWithPath: uri)
                            print("🎵 Created URL from file path: \(url)")
                        }

                        print("🎵 Final URL path: \(url.path)")
                        print("🎵 Checking if file exists at path: \(url.path)")

                        // Check if file exists
                        if !FileManager.default.fileExists(atPath: url.path) {
                            print("🎵 ❌ File does not exist at path: \(url.path)")

                            // Let's also check the original path
                            if uri.hasPrefix("file://") {
                                let originalPath = String(uri.dropFirst(7)) // Remove "file://"
                                print("🎵 Checking original path without file:// prefix: \(originalPath)")
                                if FileManager.default.fileExists(atPath: originalPath) {
                                    print("🎵 ✅ File exists at original path: \(originalPath)")
                                } else {
                                    print("🎵 ❌ File also does not exist at original path: \(originalPath)")
                                }
                            }

                            promise.reject(withError: RuntimeError.error(withMessage: "Audio file does not exist at path: \(uri)"))
                            return
                        }

                        print("🎵 ✅ File exists, creating AVAudioPlayer...")

                        self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                        self.ensurePlayerDelegate()
                        self.audioPlayer?.delegate = self.playerDelegateProxy

                        guard let player = self.audioPlayer else {
                            promise.reject(withError: RuntimeError.error(withMessage: "Failed to create audio player"))
                            return
                        }

                        player.volume = 1.0
                        player.enableRate = true
                        player.rate = Float(self.playbackRate)
                        player.prepareToPlay()

                        // Play on main queue
                        DispatchQueue.main.async {
                            self.startPlayTimer()

                            let playResult = player.play()

                            if playResult {
                                promise.resolve(withResult: uri)
                            } else {
                                self.stopPlayTimer()
                                promise.reject(withError: RuntimeError.error(withMessage: "Failed to start playback"))
                            }
                        }
                    }
                } else {
                    print("🎵 ❌ No URI provided")
                    promise.reject(withError: RuntimeError.error(withMessage: "URI is required for playback"))
                }
            } catch {
                print("🎵 ❌ Playback error: \(error)")
                promise.reject(withError: RuntimeError.error(withMessage: "Playback error: \(error.localizedDescription)"))
            }
        }

        return promise
    }

    public func stopPlayer() throws -> Promise<String> {
        let promise = Promise<String>()

        if let player = self.audioPlayer {
            player.stop()
            self.audioPlayer = nil
        }

        if let engine = self.audioEngine {
            engine.stop()
            self.audioEngine = nil
            self.audioPlayerNode = nil
            self.audioFile = nil
        }

        self.stopPlayTimer()
        promise.resolve(withResult: "Player stopped")

        return promise
    }

    public func pausePlayer() throws -> Promise<String> {
        let promise = Promise<String>()

        if let player = self.audioPlayer {
            player.pause()
            self.stopPlayTimer()
            promise.resolve(withResult: "Player paused")
        } else if let node = self.audioPlayerNode {
            node.pause()
            self.stopPlayTimer()
            promise.resolve(withResult: "Player paused")
        } else {
            promise.reject(withError: RuntimeError.error(withMessage: "No player instance"))
        }

        return promise
    }

    public func resumePlayer() throws -> Promise<String> {
        let promise = Promise<String>()

        if let player = self.audioPlayer {
            player.enableRate = true
            player.rate = Float(self.playbackRate)
            player.play()
            DispatchQueue.main.async {
                self.startPlayTimer()
            }
            promise.resolve(withResult: "Player resumed")
        } else if let node = self.audioPlayerNode {
            node.play()
            DispatchQueue.main.async {
                self.startPlayTimer()
            }
            promise.resolve(withResult: "Player resumed")
        } else {
            promise.reject(withError: RuntimeError.error(withMessage: "No player instance"))
        }

        return promise
    }

    public func seekToPlayer(time: Double) throws -> Promise<String> {
        let promise = Promise<String>()

        if let player = self.audioPlayer {
            player.currentTime = time / 1000.0 // Convert ms to seconds
            promise.resolve(withResult: "Seek completed to \(time)ms")
        } else {
            promise.reject(withError: RuntimeError.error(withMessage: "No player instance"))
        }

        return promise
    }

    public func setVolume(volume: Double) throws -> Promise<String> {
        let promise = Promise<String>()

        if let player = self.audioPlayer {
            player.volume = Float(volume)
            promise.resolve(withResult: "Volume set to \(volume)")
        } else if let engine = self.audioEngine {
            engine.mainMixerNode.outputVolume = Float(volume)
            promise.resolve(withResult: "Volume set to \(volume)")
        } else {
            promise.reject(withError: RuntimeError.error(withMessage: "No player instance"))
        }

        return promise
    }

    public func setPlaybackSpeed(playbackSpeed: Double) throws -> Promise<String> {
        let promise = Promise<String>()

        // Persist desired rate for future players/resume
        self.playbackRate = playbackSpeed

        if let player = self.audioPlayer {
            DispatchQueue.main.async {
                player.enableRate = true
                player.rate = Float(playbackSpeed)
            }
            promise.resolve(withResult: "Playback speed set to \(playbackSpeed)")
        } else {
            // No active player; apply on next start/resume
            promise.resolve(withResult: "Playback speed stored (no active player)")
        }

        return promise
    }

    // MARK: - Subscription

    public func setSubscriptionDuration(sec: Double) throws {
        self.subscriptionDuration = sec
    }

    // MARK: - Listeners

    public func addRecordBackListener(callback: @escaping (RecordBackType) -> Void) throws {
        self.recordBackListener = callback
    }

    public func removeRecordBackListener() throws {
        self.recordBackListener = nil
    }

    public func addPlayBackListener(callback: @escaping (PlayBackType) -> Void) throws {
        self.playBackListener = callback
    }

    public func removePlayBackListener() throws {
        print("🎵 Removing playback listener and stopping timer")
        self.playBackListener = nil
        self.stopPlayTimer()
    }

    public func addPlaybackEndListener(callback: @escaping (PlaybackEndType) -> Void) throws {
        self.playbackEndListener = callback
    }

    public func removePlaybackEndListener() throws {
        self.playbackEndListener = nil
    }

    // MARK: - Utility Methods

    public func mmss(secs: Double) throws -> String {
        let totalSeconds = Int(secs)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public func mmssss(milisecs: Double) throws -> String {
        let totalSeconds = Int(milisecs / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int(milisecs.truncatingRemainder(dividingBy: 1000)) / 10
        return String(format: "%02d:%02d:%02d", minutes, seconds, milliseconds)
    }

    // MARK: - Private Methods

    private func getAudioSettings(audioSets: AudioSet?) -> [String: Any] {
        var settings: [String: Any] = [:]

        // Default settings
        settings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
        settings[AVSampleRateKey] = 44100
        settings[AVNumberOfChannelsKey] = 2
        settings[AVEncoderAudioQualityKey] = AVAudioQuality.high.rawValue

        // Apply custom settings
        if let audioSets = audioSets {
            if let sampleRate = audioSets.AVSampleRateKeyIOS {
                settings[AVSampleRateKey] = sampleRate
            }
            if let channels = audioSets.AVNumberOfChannelsKeyIOS {
                settings[AVNumberOfChannelsKey] = Int(channels)
            }
            if let quality = audioSets.AVEncoderAudioQualityKeyIOS {
                let audioQuality = mapToAVAudioQuality(quality)
                settings[AVEncoderAudioQualityKey] = audioQuality
            }
            if let format = audioSets.AVFormatIDKeyIOS {
                settings[AVFormatIDKey] = getAudioFormatID(from: format)
            }
        }

        return settings
    }

    private func mapToAVAudioQuality(_ quality: AVEncoderAudioQualityIOSType) -> Int {
        switch quality {
        case .min: return AVAudioQuality.min.rawValue
        case .low: return AVAudioQuality.low.rawValue
        case .medium: return AVAudioQuality.medium.rawValue
        case .high: return AVAudioQuality.high.rawValue
        case .max: return AVAudioQuality.max.rawValue
        default:
            // Handle unexpected enum case by returning high quality as default
            return AVAudioQuality.high.rawValue
        }
    }

    private func getAudioFormatID(from format: AVEncodingOption) -> Int {
        // AVEncodingOption is an enum
        switch format {
        case .aac: return Int(kAudioFormatMPEG4AAC)
        case .alac: return Int(kAudioFormatAppleLossless)
        case .ima4: return Int(kAudioFormatAppleIMA4)
        case .lpcm: return Int(kAudioFormatLinearPCM)
        case .ulaw: return Int(kAudioFormatULaw)
        case .alaw: return Int(kAudioFormatALaw)
        case .mp1: return Int(kAudioFormatMPEGLayer1)
        case .mp2: return Int(kAudioFormatMPEGLayer2)
        case .mp4: return Int(kAudioFormatMPEG4AAC)
        case .opus: return Int(kAudioFormatOpus)
        case .amr: return Int(kAudioFormatAMR)
        case .flac: return Int(kAudioFormatFLAC)
        case .mac3, .mac6: return Int(kAudioFormatMPEG4AAC) // Default for unsupported formats
        default:
            // Handle unexpected enum case by returning AAC as default
            return Int(kAudioFormatMPEG4AAC)
        }
    }

    private func getAudioSessionMode(from mode: AVModeIOSOption) -> AVAudioSession.Mode {
        switch mode {
        case .gamechataudio:
            return .gameChat
        case .measurement:
            return .measurement
        case .movieplayback:
            return .moviePlayback
        case .spokenaudio:
            return .spokenAudio
        case .videochat:
            return .videoChat
        case .videorecording:
            return .videoRecording
        case .voicechat:
            return .voiceChat
        case .voiceprompt:
            if #available(iOS 12.0, *) {
                return .voicePrompt
            } else {
                return .default
            }
        @unknown default:
            return .default
        }
    }

    private func setupEnginePlayer(url: String, httpHeaders: Dictionary<String, String>?, promise: Promise<String>) {
        // TODO: Implement HTTP streaming with AVAudioEngine
        // For now, use basic implementation
        guard let audioURL = URL(string: url) else {
            promise.reject(withError: RuntimeError.error(withMessage: "Invalid URL"))
            return
        }

        do {
            let data = try Data(contentsOf: audioURL)
            self.audioPlayer = try AVAudioPlayer(data: data)
            self.ensurePlayerDelegate()
            self.audioPlayer?.delegate = self.playerDelegateProxy
            if let player = self.audioPlayer {
                player.enableRate = true
                player.rate = Float(self.playbackRate)
                player.prepareToPlay()
                player.play()
            }

            self.startPlayTimer()
            promise.resolve(withResult: url)
        } catch {
            promise.reject(withError: RuntimeError.error(withMessage: error.localizedDescription))
        }
    }

    // MARK: - Timer Management

    private func startRecordTimer() {
        print("🎙️ Starting record timer with interval: \(self.subscriptionDuration)")
        print("🎙️ Current thread: \(Thread.current)")
        print("🎙️ Is main thread: \(Thread.isMainThread)")

        // Ensure we're on the main thread for timer scheduling
        DispatchQueue.main.async {
            self.recordTimer = Timer.scheduledTimer(withTimeInterval: self.subscriptionDuration, repeats: true) { [weak self] _ in
            guard let self = self else {
                print("🎙️ Timer callback: self is nil")
                return
            }
            guard let recorder = self.audioRecorder else {
                print("🎙️ Timer callback: audioRecorder is nil")
                return
            }

            print("🎙️ Timer callback: recorder exists, isRecording=\(recorder.isRecording)")

            if !recorder.isRecording {
                print("🎙️ Timer callback: recorder is not recording anymore, stopping timer")
                self.stopRecordTimer()
                return
            }

            recorder.updateMeters()

            let currentTime = recorder.currentTime * 1000 // Convert to ms
            let currentMetering = recorder.averagePower(forChannel: 0)

            print("🎙️ Timer callback: currentTime=\(currentTime)ms, metering=\(currentMetering)")

            let recordBack = RecordBackType(
                isRecording: recorder.isRecording,
                currentPosition: currentTime,
                currentMetering: Double(currentMetering),
                recordSecs: currentTime
            )

            // Avoid interpolating RecordBackType directly to prevent Swift IRGen issues on Swift 6
            print("🎙️ Timer callback: calling recordBackListener (time=\(currentTime)ms, metering=\(currentMetering))")

            if let listener = self.recordBackListener {
                print("🎙️ Timer callback: recordBackListener exists, calling it")
                listener(recordBack)
            } else {
                print("🎙️ Timer callback: recordBackListener is nil - not set up yet")
            }
        }
        }
        print("🎙️ Record timer created and scheduled on main thread")
    }

    private func stopRecordTimer() {
        DispatchQueue.main.async {
            self.recordTimer?.invalidate()
            self.recordTimer = nil
        }
    }

    private func startPlayTimer() {
        print("🎵 Starting play timer with interval: \(self.subscriptionDuration)")
        print("🎵 Current thread: \(Thread.current)")
        print("🎵 Is main thread: \(Thread.isMainThread)")

        // Ensure we're on the main thread for timer scheduling
        DispatchQueue.main.async {
            self.playTimer = Timer.scheduledTimer(withTimeInterval: self.subscriptionDuration, repeats: true) { [weak self] timer in
            print("🎵 ===== TIMER CALLBACK FIRED =====")
            guard let self = self else {
                print("🎵 Play timer callback: self is nil")
                return
            }

            // First check if we should stop the timer
            guard let player = self.audioPlayer, let listener = self.playBackListener else {
                print("🎵 Play timer callback: stopping timer - player or listener is nil")
                self.stopPlayTimer()
                return
            }

            // Check if player is still playing
            if !player.isPlaying {
                print("🎵 Play timer callback: player stopped, stopping timer")

                // Send final callback if duration is available
                if player.duration > 0 {
                    let finalPlayBack = PlayBackType(
                        isMuted: false,
                        duration: player.duration * 1000,
                        currentPosition: player.duration * 1000
                    )
                    print("🎵 Sending final callback before stopping")
                    listener(finalPlayBack)

                    // Send playback end event
                    if let endListener = self.playbackEndListener {
                        let endEvent = PlaybackEndType(
                            duration: player.duration * 1000,
                            currentPosition: player.duration * 1000
                        )
                        print("🎵 Sending playback end event")
                        endListener(endEvent)
                    }
                }

                self.stopPlayTimer()
                return
            }

            let currentTime = player.currentTime * 1000 // Convert to ms
            let duration = player.duration * 1000 // Convert to ms

            print("🎵 Play timer callback: currentTime=\(currentTime)ms, duration=\(duration)ms")

            let playBack = PlayBackType(
                isMuted: false,
                duration: duration,
                currentPosition: currentTime
            )

            listener(playBack)

            // Check if playback finished - use a small threshold for floating point comparison
            let threshold = 100.0 // 100ms threshold
            if duration > 0 && currentTime >= (duration - threshold) {
                print("🎵 Play timer callback: playback finished by position")

                // Send playback end event
                if let endListener = self.playbackEndListener {
                    let endEvent = PlaybackEndType(
                        duration: duration,
                        currentPosition: duration
                    )
                    print("🎵 Sending playback end event (threshold)")
                    endListener(endEvent)
                }

                self.stopPlayTimer()
                return
            }
        }
        }
        print("🎵 Play timer created and scheduled on main thread")
    }

    private func stopPlayTimer() {
        self.playTimer?.invalidate()
        self.playTimer = nil
    }

    // MARK: - AVAudioPlayerDelegate via proxy
    private class AudioPlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
        weak var owner: HybridSound?
        init(owner: HybridSound) { self.owner = owner }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            print("🎵 AVAudioPlayer finished playing. success=\(flag)")
            guard let owner = owner else { return }
            let finalDurationMs = player.duration * 1000
            if let listener = owner.playBackListener {
                let finalPlayBack = PlayBackType(
                    isMuted: false,
                    duration: finalDurationMs,
                    currentPosition: finalDurationMs
                )
                listener(finalPlayBack)
            }
            if let endListener = owner.playbackEndListener {
                let endEvent = PlaybackEndType(
                    duration: finalDurationMs,
                    currentPosition: finalDurationMs
                )
                endListener(endEvent)
            }
            owner.stopPlayTimer()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            print("🎵 AVAudioPlayer decode error: \(String(describing: error))")
        }
    }

    private var playerDelegateProxy: AudioPlayerDelegateProxy?
    private func ensurePlayerDelegate() {
        if playerDelegateProxy == nil { playerDelegateProxy = AudioPlayerDelegateProxy(owner: self) }
        else { playerDelegateProxy?.owner = self }
    }
}
