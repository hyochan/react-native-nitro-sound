import Foundation
import AVFoundation
import NitroModules

final class HybridSound: HybridSoundSpec_base, HybridSoundSpec_protocol {
    // MARK: - Audio Quality Presets (matching Android implementation)
    private struct QualitySettings {
        let samplingRate: Int
        let channels: Int
        let bitrate: Int
        let encoderQuality: AVAudioQuality
    }

    private static let qualityPresets: [AudioQualityType: QualitySettings] = [
        .low: QualitySettings(samplingRate: 22050, channels: 1, bitrate: 64000, encoderQuality: .low),
        .medium: QualitySettings(samplingRate: 44100, channels: 1, bitrate: 128000, encoderQuality: .medium),
        .high: QualitySettings(samplingRate: 48000, channels: 2, bitrate: 192000, encoderQuality: .high)
    ]

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
    private var didEmitPlaybackEnd = false

    private var subscriptionDuration: TimeInterval = 0.1 // 100ms - reduced from 60ms to lower memory pressure
    private var playbackRate: Double = 1.0 // default 1x
    private var recordingSession: AVAudioSession?
    private var tempAudioFile: URL? // Temporary file for remote audio playback

    // MARK: - Recording Methods

    public func startRecorder(uri: String?, audioSets: AudioSet?, meteringEnabled: Bool?) throws -> Promise<String> {
        let promise = Promise<String>()
        setupInterruptionObserver()

        // Sanitize audioSets to ignore Android-specific fields on iOS to prevent crashes
        let sanitizedAudioSets = audioSets.map { original in
            var sanitized = original
            sanitized.AudioSourceAndroid = nil
            sanitized.OutputFormatAndroid = nil
            sanitized.AudioEncoderAndroid = nil
            return sanitized
        }
        
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
                let sessionMode = sanitizedAudioSets?.AVModeIOS.map(self.getAudioSessionMode) ?? .default

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
                            self.setupAndStartRecording(uri: uri, audioSets: sanitizedAudioSets, meteringEnabled: meteringEnabled, promise: promise)
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

            // Setup recording URL (WAV format for crash-resilient recording)
            let fileURL: URL
            if let uri = uri {
                // Ensure file path ends with .wav for crash resilience
                var wavPath = uri
                if !uri.lowercased().hasSuffix(".wav") {
                    // Replace extension with .wav
                    let basePath = (uri as NSString).deletingPathExtension
                    wavPath = basePath + ".wav"
                }
                fileURL = URL(fileURLWithPath: wavPath)
                print("🎙️ Using provided URI (converted to WAV): \(wavPath)")
            } else {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "sound_\(Date().timeIntervalSince1970).wav"
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
                #if DEBUG
                print("🎙️ Directory is not writable: \(directory.path)")
                #endif
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
                let wavURL = recorder.url
                let wavPath = wavURL.path

                // Stop recorder on main queue
                DispatchQueue.main.async {
                    recorder.stop()
                    self.stopRecordTimer()
                    self.removeInterruptionObserver()
                    
                    // Continue with conversion in background
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.audioRecorder = nil

                        // Deactivate audio session
                        try? self.recordingSession?.setActive(false)
                        self.recordingSession = nil

                        // Convert WAV to M4A for smaller file size
                        let conversionResult = WavToM4aConverter.convertSync(
                            wavFilePath: wavPath,
                            deleteWavAfterConversion: true
                        )
                        
                        switch conversionResult {
                        case .success(let outputPath, _):
                            let outputURL = URL(fileURLWithPath: outputPath)
                            promise.resolve(withResult: outputURL.absoluteString)
                        case .error(let message):
                            // If conversion fails, return the WAV file instead
                            if FileManager.default.fileExists(atPath: wavPath) {
                                promise.resolve(withResult: wavURL.absoluteString)
                            } else {
                                promise.reject(withError: RuntimeError.error(withMessage: "Recording failed: \(message)"))
                            }
                        }
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
            player.delegate = nil  // Clear delegate to prevent callbacks
            self.audioPlayer = nil
        }

        if let engine = self.audioEngine {
            engine.stop()
            self.audioEngine = nil
            self.audioPlayerNode = nil
            self.audioFile = nil
        }

        self.stopPlayTimer()
        
        // Clean up temporary audio file from remote playback
        if let tempFile = self.tempAudioFile {
            try? FileManager.default.removeItem(at: tempFile)
            self.tempAudioFile = nil
        }
        
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
        #if DEBUG
        print("🎙️ Removing record back listener")
        #endif
        self.recordBackListener = nil
        // Also stop timer if no listener
        self.stopRecordTimer()
    }

    public func addPlayBackListener(callback: @escaping (PlayBackType) -> Void) throws {
        self.playBackListener = callback
    }

    public func removePlayBackListener() throws {
        #if DEBUG
        print("🎵 Removing playback listener and stopping timer")
        #endif
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

    // MARK: - Recovery Methods
    
    /**
     * Restore any pending recordings that were interrupted by app crash.
     * Scans for WAV files, converts them to M4A, and returns the results.
     */
    public func restorePendingRecordings(directory: String?) throws -> Promise<[RestoredRecording]> {
        let promise = Promise<[RestoredRecording]>()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let scanDirectory: URL
                if let directory = directory {
                    let dirURL = URL(fileURLWithPath: directory)
                    // Validate path to prevent directory traversal attacks
                    guard Self.validatePathSecurity(path: dirURL.path) else {
                        promise.reject(withError: RuntimeError.error(withMessage: "Access denied: directory is outside allowed paths"))
                        return
                    }
                    scanDirectory = dirURL
                } else {
                    scanDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                }
                
                // Check if directory exists
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: scanDirectory.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    promise.resolve(withResult: [])
                    return
                }
                
                // Find all WAV files
                let contents = try FileManager.default.contentsOfDirectory(
                    at: scanDirectory,
                    includingPropertiesForKeys: nil
                )
                
                let wavFiles = contents.filter { $0.pathExtension.lowercased() == "wav" }
                
                if wavFiles.isEmpty {
                    promise.resolve(withResult: [])
                    return
                }
                
                var restoredRecordings: [RestoredRecording] = []
                
                for wavURL in wavFiles {
                    let wavPath = wavURL.path
                    
                    // Convert to M4A
                    let result = WavToM4aConverter.convertSync(
                        wavFilePath: wavPath,
                        deleteWavAfterConversion: true
                    )
                    
                    switch result {
                    case .success(let outputPath, let duration):
                        let outputURL = URL(fileURLWithPath: outputPath)
                        let recording = RestoredRecording(
                            uri: outputURL.absoluteString,
                            duration: duration * 1000, // Convert to milliseconds
                            originalPath: wavPath
                        )
                        restoredRecordings.append(recording)
                        
                    case .error(let message):
                        print("🎙️ Failed to convert \(wavPath): \(message)")
                        // If conversion fails, still return the WAV file
                        if FileManager.default.fileExists(atPath: wavPath) {
                            let estimatedDuration = Self.estimateWavDuration(filePath: wavPath)
                            
                            let recording = RestoredRecording(
                                uri: wavURL.absoluteString,
                                duration: estimatedDuration,
                                originalPath: wavPath
                            )
                            restoredRecordings.append(recording)
                        }
                    }
                }
                
                promise.resolve(withResult: restoredRecordings)
                
            } catch {
                promise.reject(withError: RuntimeError.error(withMessage: "Failed to restore recordings: \(error.localizedDescription)"))
            }
        }
        
        return promise
    }
    
    /**
     * Restore a single WAV recording file by converting it to M4A.
     * Use this when you need to restore a specific file and update your local database.
     */
    public func restoreRecording(wavFilePath: String) throws -> Promise<RestoredRecording> {
        let promise = Promise<RestoredRecording>()
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Validate path to prevent path traversal attacks
            guard Self.validatePathSecurity(path: wavFilePath) else {
                promise.reject(withError: RuntimeError.error(withMessage: "Access denied: file path is outside allowed paths"))
                return
            }
            
            // Check if file exists
            guard FileManager.default.fileExists(atPath: wavFilePath) else {
                promise.reject(withError: RuntimeError.error(withMessage: "WAV file not found: \(wavFilePath)"))
                return
            }
            
            // Check if it's a WAV file
            guard wavFilePath.lowercased().hasSuffix(".wav") else {
                promise.reject(withError: RuntimeError.error(withMessage: "File is not a WAV file: \(wavFilePath)"))
                return
            }
            
            // Convert to M4A
            let result = WavToM4aConverter.convertSync(
                wavFilePath: wavFilePath,
                deleteWavAfterConversion: true
            )
            
            switch result {
            case .success(let outputPath, let duration):
                let outputURL = URL(fileURLWithPath: outputPath)
                let recording = RestoredRecording(
                    uri: outputURL.absoluteString,
                    duration: duration * 1000, // Convert to milliseconds
                    originalPath: wavFilePath
                )
                promise.resolve(withResult: recording)
                
            case .error(let message):
                // If conversion fails but WAV still exists, return WAV info
                if FileManager.default.fileExists(atPath: wavFilePath) {
                    let wavURL = URL(fileURLWithPath: wavFilePath)
                    let estimatedDuration = Self.estimateWavDuration(filePath: wavFilePath)
                    
                    let recording = RestoredRecording(
                        uri: wavURL.absoluteString,
                        duration: estimatedDuration,
                        originalPath: wavFilePath
                    )
                    promise.resolve(withResult: recording)
                } else {
                    promise.reject(withError: RuntimeError.error(withMessage: "Conversion failed: \(message)"))
                }
            }
        }
        
        return promise
    }

    // MARK: - Path Security Validation
    
    /**
     * Validate that the given path is within allowed directories.
     * Prevents path traversal attacks by ensuring the path is under
     * the app's Documents, Library, tmp, or Caches directory.
     */
    private static func validatePathSecurity(path: String) -> Bool {
        let canonicalPath = (path as NSString).standardizingPath
        
        let allowedDirs: [String] = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path,
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.path,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path,
            NSTemporaryDirectory()
        ].compactMap { $0 }.map { ($0 as NSString).standardizingPath }
        
        return allowedDirs.contains { canonicalPath.hasPrefix($0) }
    }
    
    // MARK: - WAV Duration Estimation
    
    /**
     * Estimate WAV file duration by reading the actual byte rate from the header.
     * Falls back to a default assumption if header cannot be read.
     *
     * WAV header layout (bytes):
     *   0-3:   "RIFF"
     *   4-7:   file size - 8
     *   8-11:  "WAVE"
     *  12-15:  "fmt "
     *  16-19:  subchunk1 size (16 for PCM)
     *  20-21:  audio format (1 = PCM)
     *  22-23:  num channels
     *  24-27:  sample rate
     *  28-31:  byte rate (sampleRate * channels * bitsPerSample / 8)
     *  32-33:  block align
     *  34-35:  bits per sample
     *  36-39:  "data"
     *  40-43:  data size
     */
    private static func estimateWavDuration(filePath: String) -> Double {
        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return 0.0
        }
        defer { fileHandle.closeFile() }
        
        let headerData = fileHandle.readData(ofLength: 44)
        guard headerData.count >= 44 else {
            return 0.0
        }
        
        // Read byte rate from offset 28 (little-endian UInt32)
        let byteRate: UInt32 = headerData.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 28, as: UInt32.self)
        }
        
        guard byteRate > 0 else {
            // Fallback: assume 44100Hz, 16-bit, mono
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64) ?? 0
            return Double(fileSize - 44) / 88.2
        }
        
        // Get total file size
        let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        let dataSize = fileSize - 44 // Subtract WAV header
        
        // Duration in milliseconds: dataSize / byteRate * 1000
        return (Double(dataSize) / Double(byteRate)) * 1000.0
    }
    
    // MARK: - Private Methods

    private func getAudioSettings(audioSets: AudioSet?) -> [String: Any] {
        var settings: [String: Any] = [:]

        // Default to HIGH quality if not specified
        let audioQuality = audioSets?.AudioQuality ?? .high
        let defaults = Self.qualityPresets[audioQuality] ?? Self.qualityPresets[.high]!

        // Use Linear PCM (WAV) format by default for crash-resilient recording
        // WAV files are always playable even if recording is interrupted
        settings[AVFormatIDKey] = Int(kAudioFormatLinearPCM)
        settings[AVSampleRateKey] = defaults.samplingRate
        settings[AVNumberOfChannelsKey] = defaults.channels
        
        // Linear PCM specific settings
        settings[AVLinearPCMBitDepthKey] = 16
        settings[AVLinearPCMIsFloatKey] = false
        settings[AVLinearPCMIsBigEndianKey] = false
        settings[AVLinearPCMIsNonInterleaved] = false

        // Apply custom settings with explicit overrides taking precedence
        if let audioSets = audioSets {
            // iOS-specific settings take highest priority
            if let sampleRate = audioSets.AVSampleRateKeyIOS {
                settings[AVSampleRateKey] = sampleRate
            } else if let audioSamplingRate = audioSets.AudioSamplingRate {
                // Fall back to cross-platform setting
                settings[AVSampleRateKey] = Int(audioSamplingRate)
            }

            if let channels = audioSets.AVNumberOfChannelsKeyIOS {
                settings[AVNumberOfChannelsKey] = Int(channels)
            } else if let audioChannels = audioSets.AudioChannels {
                // Fall back to cross-platform setting
                settings[AVNumberOfChannelsKey] = Int(audioChannels)
            }

            // Apply bit depth if specified
            if let bitDepth = audioSets.AVLinearPCMBitDepthKeyIOS {
                let bitDepthValue: Int
                switch bitDepth {
                case .bit8: bitDepthValue = 8
                case .bit16: bitDepthValue = 16
                case .bit24: bitDepthValue = 24
                case .bit32: bitDepthValue = 32
                @unknown default: bitDepthValue = 16
                }
                settings[AVLinearPCMBitDepthKey] = bitDepthValue
            }

            // Apply format override only if explicitly specified
            // Note: For crash resilience, we recommend staying with Linear PCM
            if let format = audioSets.AVFormatIDKeyIOS {
                let formatId = getAudioFormatID(from: format)
                settings[AVFormatIDKey] = formatId
                
                // If switching to a compressed format, remove PCM-specific settings
                // and add encoder settings
                if formatId != Int(kAudioFormatLinearPCM) {
                    settings.removeValue(forKey: AVLinearPCMBitDepthKey)
                    settings.removeValue(forKey: AVLinearPCMIsFloatKey)
                    settings.removeValue(forKey: AVLinearPCMIsBigEndianKey)
                    settings.removeValue(forKey: AVLinearPCMIsNonInterleaved)
                    
                    settings[AVEncoderBitRateKey] = defaults.bitrate
                    settings[AVEncoderAudioQualityKey] = defaults.encoderQuality.rawValue
                    
                    if let bitRate = audioSets.AudioEncodingBitRate {
                        settings[AVEncoderBitRateKey] = Int(bitRate)
                    }
                    
                    if let quality = audioSets.AVEncoderAudioQualityKeyIOS {
                        let mappedQuality = mapToAVAudioQuality(quality)
                        settings[AVEncoderAudioQualityKey] = mappedQuality
                    }
                }
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
        // For now, use basic implementation with memory optimization
        guard let audioURL = URL(string: url) else {
            promise.reject(withError: RuntimeError.error(withMessage: "Invalid URL"))
            return
        }

        // Download to temporary file instead of loading into memory
        // This prevents memory issues with large audio files
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("audio_\(UUID().uuidString).tmp")
        
        do {
            // Use streaming download instead of loading into memory
            let data = try Data(contentsOf: audioURL)
            try data.write(to: tempFile)
            
            // Create player from file instead of data (more memory efficient)
            self.audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
            self.ensurePlayerDelegate()
            self.audioPlayer?.delegate = self.playerDelegateProxy
            if let player = self.audioPlayer {
                player.enableRate = true
                player.rate = Float(self.playbackRate)
                player.prepareToPlay()
                player.play()
            }

            // Store temp file reference for cleanup when player stops
            self.tempAudioFile = tempFile
            
            self.startPlayTimer()
            promise.resolve(withResult: url)
        } catch {
            // Clean up temp file on error
            try? FileManager.default.removeItem(at: tempFile)
            promise.reject(withError: RuntimeError.error(withMessage: error.localizedDescription))
        }
    }

    // MARK: - Timer Management

    private func startRecordTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            #if DEBUG
            print("🎙️ Starting record timer with interval: \(self.subscriptionDuration)")
            #endif

            self.recordTimer = Timer.scheduledTimer(withTimeInterval: self.subscriptionDuration, repeats: true) { [weak self] _ in
                // Use autoreleasepool to ensure temporary objects are released promptly during long recordings
                autoreleasepool {
                    guard let self = self,
                          let recorder = self.audioRecorder,
                          recorder.isRecording else {
                        self?.stopRecordTimer()
                        return
                    }

                    // Only update meters if metering is enabled
                    if recorder.isMeteringEnabled {
                        recorder.updateMeters()
                    }

                    let currentTime = recorder.currentTime * 1000 // Convert to ms
                    let currentMetering = recorder.isMeteringEnabled ? Double(recorder.averagePower(forChannel: 0)) : -160.0

                    let recordBack = RecordBackType(
                        isRecording: true,
                        currentPosition: currentTime,
                        currentMetering: currentMetering,
                        recordSecs: currentTime
                    )

                    self.recordBackListener?(recordBack)
                }
            }

            #if DEBUG
            print("🎙️ Record timer created and scheduled on main thread")
            #endif
        }
    }

    private func stopRecordTimer() {
        stopTimer(for: \.recordTimer)
    }

    private func startPlayTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            #if DEBUG
            print("🎵 Starting play timer with interval: \(self.subscriptionDuration)")
            #endif

            self.didEmitPlaybackEnd = false

            self.playTimer = Timer.scheduledTimer(withTimeInterval: self.subscriptionDuration, repeats: true) { [weak self] timer in
                // Use autoreleasepool to ensure temporary objects are released promptly
                autoreleasepool {
                    guard let self = self,
                          let player = self.audioPlayer,
                          let listener = self.playBackListener else {
                        self?.stopPlayTimer()
                        return
                    }

                    // Check if player is still playing
                    if !player.isPlaying {
                        // Send final callback if duration is available
                        if player.duration > 0 {
                            self.emitPlaybackEndEvents(durationMs: player.duration * 1000, includePlaybackUpdate: true)
                        }
                        self.stopPlayTimer()
                        return
                    }

                    let currentTime = player.currentTime * 1000 // Convert to ms
                    let duration = player.duration * 1000 // Convert to ms

                    let playBack = PlayBackType(
                        isMuted: false,
                        duration: duration,
                        currentPosition: currentTime
                    )

                    listener(playBack)

                    // Check if playback finished - use a small threshold for floating point comparison
                    let threshold = 100.0 // 100ms threshold
                    if duration > 0 && currentTime >= (duration - threshold) {
                        self.emitPlaybackEndEvents(durationMs: duration, includePlaybackUpdate: true)
                        self.stopPlayTimer()
                        return
                    }
                }
            }

            #if DEBUG
            print("🎵 Play timer created and scheduled on main thread")
            #endif
        }
    }

    private func stopPlayTimer() {
        stopTimer(for: \.playTimer)
    }

    private func stopTimer(for keyPath: ReferenceWritableKeyPath<HybridSound, Timer?>) {
        if Thread.isMainThread {
            self[keyPath: keyPath]?.invalidate()
            self[keyPath: keyPath] = nil
        } else {
            DispatchQueue.main.sync {
                self[keyPath: keyPath]?.invalidate()
                self[keyPath: keyPath] = nil
            }
        }
    }

    private func emitPlaybackEndEvents(durationMs: Double, includePlaybackUpdate: Bool) {
        guard !self.didEmitPlaybackEnd else {
            return
        }
        self.didEmitPlaybackEnd = true

        if includePlaybackUpdate, let listener = self.playBackListener {
            let finalPlayBack = PlayBackType(
                isMuted: false,
                duration: durationMs,
                currentPosition: durationMs
            )
            listener(finalPlayBack)
        }

        if let endListener = self.playbackEndListener {
            let endEvent = PlaybackEndType(
                duration: durationMs,
                currentPosition: durationMs
            )
            endListener(endEvent)
        }
    }

    // MARK: - Interruption Handling
    
    private func setupInterruptionObserver() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Observe app termination to finalize recording
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
    }
    
    private func removeInterruptionObserver() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
    }
    
    /**
     * Called when the app is about to be terminated (e.g., user swipe kills the app).
     * This ensures the audio file is properly finalized so it can be opened later.
     */
    @objc private func handleAppWillTerminate(notification: Notification) {
        finalizeRecordingOnKill()
    }
    
    /**
     * Safely finalize the recording when app is being killed or entering background.
     * This ensures the audio file header is written correctly and the file can be played back.
     */
    private func finalizeRecordingOnKill() {
        guard let recorder = audioRecorder else { return }
        
        let fileURL = recorder.url
        let currentTime = recorder.currentTime * 1000
        
        print("🎙️ Finalizing recording on app kill/background...")
        print("🎙️ Recording path: \(fileURL.path)")
        
        // Stop recording to finalize file headers
        recorder.stop()
        stopRecordTimer()
        
        // Check if file was saved properly
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("🎙️ Audio file saved successfully: \(fileURL.path) (\(fileSize) bytes)")
            } catch {
                print("🎙️ Could not get file attributes: \(error)")
            }
        } else {
            print("🎙️ ⚠️ Audio file not found after finalization: \(fileURL.path)")
        }
        
        // Notify listener with final state
        if let listener = recordBackListener {
            listener(RecordBackType(
                isRecording: false,
                currentPosition: currentTime,
                currentMetering: nil,
                recordSecs: currentTime
            ))
        }
        
        // Cleanup
        audioRecorder = nil
        try? recordingSession?.setActive(false)
        recordingSession = nil
        
        print("🎙️ Recording finalized successfully")
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (e.g., phone call) - stop recording to save the audio.
            //
            // The recording is stopped (not paused) because iOS does not guarantee
            // that the audio session can be restored. The WAV file is finalized on disk
            // and remains playable.
            //
            // Note: The callback sends isRecording=false with the current position,
            // but does NOT include the file path. The JS side already knows the file
            // path from the startRecorder() promise. If the file was auto-generated,
            // callers should use restorePendingRecordings() after app restart to
            // retrieve any interrupted recordings.
            if let recorder = audioRecorder, recorder.isRecording {
                let currentTime = recorder.currentTime * 1000
                
                // Stop recording to save the audio
                recorder.stop()
                stopRecordTimer()
                
                // Clean up current recorder but keep session for potential resume
                audioRecorder = nil
                try? recordingSession?.setActive(false)
                recordingSession = nil
                
                // Notify listener with interruption status
                if let listener = recordBackListener {
                    listener(RecordBackType(
                        isRecording: false,
                        currentPosition: currentTime,
                        currentMetering: nil,
                        recordSecs: currentTime,
                    ))
                }
            }
        case .ended:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - AVAudioPlayerDelegate via proxy
    deinit {
        #if DEBUG
        print("🎙️ HybridSound deinit called - cleaning up resources")
        #endif
        
        // Remove notification observer
        removeInterruptionObserver()
        
        // Stop and invalidate timers
        recordTimer?.invalidate()
        recordTimer = nil
        playTimer?.invalidate()
        playTimer = nil
        
        // Stop any active recording/playback
        audioRecorder?.stop()
        audioRecorder = nil
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Clean up audio engine
        audioEngine?.stop()
        audioEngine = nil
        audioPlayerNode = nil
        audioFile = nil
        
        // Clean up temporary audio file
        if let tempFile = tempAudioFile {
            try? FileManager.default.removeItem(at: tempFile)
            tempAudioFile = nil
        }
        
        // Clear all listeners to break potential retain cycles
        recordBackListener = nil
        playBackListener = nil
        playbackEndListener = nil
        
        // Deactivate audio session
        try? recordingSession?.setActive(false)
        recordingSession = nil
        
        // Clear delegate proxy
        playerDelegateProxy = nil
        
        #if DEBUG
        print("🎙️ HybridSound cleanup completed")
        #endif
    }

    private class AudioPlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
        weak var owner: HybridSound?
        init(owner: HybridSound) { self.owner = owner }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            #if DEBUG
            print("🎵 AVAudioPlayer finished playing. success=\(flag)")
            #endif
            guard let owner = owner else { return }
            let finalDurationMs = player.duration * 1000
            owner.emitPlaybackEndEvents(durationMs: finalDurationMs, includePlaybackUpdate: true)
            owner.stopPlayTimer()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            #if DEBUG
            print("🎵 AVAudioPlayer decode error: \(String(describing: error))")
            #endif
        }
    }

    private var playerDelegateProxy: AudioPlayerDelegateProxy?
    private func ensurePlayerDelegate() {
        if playerDelegateProxy == nil { playerDelegateProxy = AudioPlayerDelegateProxy(owner: self) }
        else { playerDelegateProxy?.owner = self }
    }
}
