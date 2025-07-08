import Foundation
import AVFoundation
import NitroModules

class HybridAudioRecorderPlayer: HybridAudioRecorderPlayerSpec {
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVPlayer?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    private var recordTimer: Timer?
    private var playbackTimer: Timer?
    
    private var recordingCallback: ((RecordBackType) -> Void)?
    private var playbackCallback: ((PlayBackType) -> Void)?
    
    private var subscriptionDuration: Double = 0.5
    private var pausedRecordTime: Double = 0
    private var pausedPlayTime: Double = 0
    private var totalDuration: Double = 0
    
    private var recordFilePath: String?
    private var isRecording = false
    private var isPaused = false
    private var isPlayerPaused = false
    
    // MARK: - Memory Holder
    override var memorySize: Int {
        return 64
    }
    
    // MARK: - Recording Methods
    func startRecorder(uri: String?, audioSets: AudioSet?, meteringEnabled: Bool) -> Promise<String> {
        return Promise.async {
            var url: URL
            
            if let uri = uri, !uri.isEmpty {
                url = URL(fileURLWithPath: uri)
                self.recordFilePath = uri
            } else {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let fileName = "sound_\(Date().timeIntervalSince1970).m4a"
                url = URL(fileURLWithPath: documentsPath).appendingPathComponent(fileName)
                self.recordFilePath = url.path
            }
            
            // Configure audio session
            let audioSessionMode = audioSets?.AVModeIOS ?? AVAudioSession.Mode.default.rawValue
            try self.audioSession.setCategory(.playAndRecord, mode: AVAudioSession.Mode(rawValue: audioSessionMode) ?? .default)
            try self.audioSession.setActive(true)
            
            // Configure audio settings
            var settings: [String: Any] = [:]
            
            if let formatID = audioSets?.AVFormatIDKeyIOS {
                settings[AVFormatIDKey] = self.getAudioFormat(from: formatID)
            } else {
                settings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
            }
            
            if let sampleRate = audioSets?.AVSampleRateKeyIOS {
                settings[AVSampleRateKey] = sampleRate
            } else {
                settings[AVSampleRateKey] = 44100.0
            }
            
            if let numberOfChannels = audioSets?.AVNumberOfChannelsKeyIOS {
                settings[AVNumberOfChannelsKey] = numberOfChannels
            } else {
                settings[AVNumberOfChannelsKey] = 2
            }
            
            if let encoderQuality = audioSets?.AVEncoderAudioQualityKeyIOS {
                settings[AVEncoderAudioQualityKey] = encoderQuality
            } else {
                settings[AVEncoderAudioQualityKey] = AVAudioQuality.high.rawValue
            }
            
            // Create and start recorder
            self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            self.audioRecorder?.isMeteringEnabled = meteringEnabled
            self.audioRecorder?.prepareToRecord()
            self.audioRecorder?.record()
            
            self.isRecording = true
            self.isPaused = false
            self.pausedRecordTime = 0
            
            // Start timer for progress updates
            self.startRecordTimer()
            
            return self.recordFilePath ?? ""
        }
    }
    
    func pauseRecorder() -> Promise<String> {
        return Promise.async {
            guard let recorder = self.audioRecorder, recorder.isRecording else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No recording in progress"])
            }
            
            self.pausedRecordTime = recorder.currentTime
            recorder.pause()
            self.isPaused = true
            self.stopRecordTimer()
            
            return "Recording paused"
        }
    }
    
    func resumeRecorder() -> Promise<String> {
        return Promise.async {
            guard let recorder = self.audioRecorder else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No recording session"])
            }
            
            recorder.record()
            self.isPaused = false
            self.startRecordTimer()
            
            return "Recording resumed"
        }
    }
    
    func stopRecorder() -> Promise<String> {
        return Promise.async {
            guard let recorder = self.audioRecorder else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No recording session"])
            }
            
            recorder.stop()
            self.isRecording = false
            self.isPaused = false
            self.stopRecordTimer()
            
            let path = self.recordFilePath ?? ""
            self.recordFilePath = nil
            self.audioRecorder = nil
            
            return path
        }
    }
    
    // MARK: - Playback Methods
    func startPlayer(uri: String?, httpHeaders: Record<String, String>?) -> Promise<String> {
        return Promise.async {
            let url: URL
            
            if let uri = uri, !uri.isEmpty {
                if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
                    guard let remoteUrl = URL(string: uri) else {
                        throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    }
                    url = remoteUrl
                } else {
                    url = URL(fileURLWithPath: uri)
                }
            } else {
                guard let recordPath = self.recordFilePath else {
                    throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file to play"])
                }
                url = URL(fileURLWithPath: recordPath)
            }
            
            // Configure audio session
            try self.audioSession.setCategory(.playback)
            try self.audioSession.setActive(true)
            
            // Create player item
            let playerItem: AVPlayerItem
            if let headers = httpHeaders, !headers.isEmpty {
                let options = ["AVURLAssetHTTPHeaderFieldsKey": headers]
                let asset = AVURLAsset(url: url, options: options)
                playerItem = AVPlayerItem(asset: asset)
            } else {
                playerItem = AVPlayerItem(url: url)
            }
            
            // Create and configure player
            self.audioPlayer = AVPlayer(playerItem: playerItem)
            self.audioPlayer?.play()
            
            self.isPlayerPaused = false
            self.pausedPlayTime = 0
            
            // Get duration
            if let duration = playerItem.asset.duration.seconds, !duration.isNaN {
                self.totalDuration = duration
            }
            
            // Start timer for progress updates
            self.startPlaybackTimer()
            
            return url.absoluteString
        }
    }
    
    func pausePlayer() -> Promise<String> {
        return Promise.async {
            guard let player = self.audioPlayer else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No playback in progress"])
            }
            
            self.pausedPlayTime = player.currentTime().seconds
            player.pause()
            self.isPlayerPaused = true
            self.stopPlaybackTimer()
            
            return "Playback paused"
        }
    }
    
    func resumePlayer() -> Promise<String> {
        return Promise.async {
            guard let player = self.audioPlayer else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No playback session"])
            }
            
            player.play()
            self.isPlayerPaused = false
            self.startPlaybackTimer()
            
            return "Playback resumed"
        }
    }
    
    func stopPlayer() -> Promise<String> {
        return Promise.async {
            guard let player = self.audioPlayer else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No playback session"])
            }
            
            player.pause()
            player.seek(to: CMTime.zero)
            self.isPlayerPaused = false
            self.stopPlaybackTimer()
            
            self.audioPlayer = nil
            
            return "Playback stopped"
        }
    }
    
    func seekToPlayer(time: Double) -> Promise<String> {
        return Promise.async {
            guard let player = self.audioPlayer else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No playback session"])
            }
            
            let cmTime = CMTime(seconds: time / 1000.0, preferredTimescale: 1000)
            player.seek(to: cmTime)
            
            return "Seeked to \(time)ms"
        }
    }
    
    func setVolume(volume: Double) -> Promise<String> {
        return Promise.async {
            guard let player = self.audioPlayer else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No playback session"])
            }
            
            player.volume = Float(volume)
            
            return "Volume set to \(volume)"
        }
    }
    
    func setPlaybackSpeed(playbackSpeed: Double) -> Promise<String> {
        return Promise.async {
            guard let player = self.audioPlayer else {
                throw NSError(domain: "AudioRecorderPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No playback session"])
            }
            
            player.rate = Float(playbackSpeed)
            
            return "Playback speed set to \(playbackSpeed)"
        }
    }
    
    func setSubscriptionDuration(sec: Double) -> Promise<String> {
        return Promise.async {
            self.subscriptionDuration = sec
            return "Subscription duration set to \(sec)s"
        }
    }
    
    // MARK: - Event Listeners
    func onRecordingProgress(callback: @escaping (RecordBackType) -> Void) -> Func_void {
        self.recordingCallback = callback
        return Func_void {
            self.recordingCallback = nil
        }
    }
    
    func onPlaybackProgress(callback: @escaping (PlayBackType) -> Void) -> Func_void {
        self.playbackCallback = callback
        return Func_void {
            self.playbackCallback = nil
        }
    }
    
    // MARK: - Private Methods
    private func getAudioFormat(from formatString: String) -> AudioFormatID {
        switch formatString {
        case "lpcm":
            return kAudioFormatLinearPCM
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
        case "alac":
            return kAudioFormatAppleLossless
        case "amr":
            return kAudioFormatAMR
        case "flac":
            return kAudioFormatFLAC
        case "opus":
            return kAudioFormatOpus
        default:
            return kAudioFormatMPEG4AAC
        }
    }
    
    private func startRecordTimer() {
        self.recordTimer?.invalidate()
        self.recordTimer = Timer.scheduledTimer(withTimeInterval: self.subscriptionDuration, repeats: true) { _ in
            guard let recorder = self.audioRecorder else { return }
            
            let currentTime = recorder.currentTime + self.pausedRecordTime
            var metering: Double = 0
            
            if recorder.isMeteringEnabled {
                recorder.updateMeters()
                metering = Double(recorder.averagePower(forChannel: 0))
            }
            
            let data = RecordBackType(
                isRecording: self.isRecording && !self.isPaused,
                currentPosition: currentTime * 1000,
                currentMetering: metering
            )
            
            self.recordingCallback?(data)
        }
    }
    
    private func stopRecordTimer() {
        self.recordTimer?.invalidate()
        self.recordTimer = nil
    }
    
    private func startPlaybackTimer() {
        self.playbackTimer?.invalidate()
        self.playbackTimer = Timer.scheduledTimer(withTimeInterval: self.subscriptionDuration, repeats: true) { _ in
            guard let player = self.audioPlayer else { return }
            
            let currentTime = player.currentTime().seconds
            let duration = self.totalDuration
            let isFinished = currentTime >= duration && duration > 0
            
            let data = PlayBackType(
                isMuted: player.volume == 0,
                currentPosition: currentTime * 1000,
                duration: duration * 1000,
                isFinished: isFinished
            )
            
            self.playbackCallback?(data)
            
            if isFinished {
                self.stopPlaybackTimer()
            }
        }
    }
    
    private func stopPlaybackTimer() {
        self.playbackTimer?.invalidate()
        self.playbackTimer = nil
    }
}