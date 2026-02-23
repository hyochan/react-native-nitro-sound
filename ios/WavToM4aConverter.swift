import Foundation
import AVFoundation

/**
 * Converts WAV audio files to M4A (AAC) format.
 *
 * Uses AVAssetReader and AVAssetWriter for efficient conversion.
 * This allows recording in crash-resilient WAV format, then converting
 * to smaller M4A format after successful recording.
 */
class WavToM4aConverter {
    
    /// Result of conversion operation
    enum ConversionResult {
        case success(outputPath: String, duration: TimeInterval)
        case error(message: String)
    }
    
    /// Default AAC bit rate
    private static let defaultBitRate = 128000
    
    /**
     * Convert a WAV file to M4A format.
     *
     * - Parameters:
     *   - wavFilePath: Path to the input WAV file
     *   - m4aFilePath: Optional output path. If nil, will use same path with .m4a extension
     *   - bitRate: Target bit rate for AAC encoding (default: 128kbps)
     *   - deleteWavAfterConversion: Whether to delete the WAV file after successful conversion
     *   - completion: Callback with conversion result
     */
    static func convert(
        wavFilePath: String,
        m4aFilePath: String? = nil,
        bitRate: Int = defaultBitRate,
        deleteWavAfterConversion: Bool = true,
        completion: @escaping (ConversionResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = convertSync(
                wavFilePath: wavFilePath,
                m4aFilePath: m4aFilePath,
                bitRate: bitRate,
                deleteWavAfterConversion: deleteWavAfterConversion
            )
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /**
     * Synchronous version of convert.
     */
    static func convertSync(
        wavFilePath: String,
        m4aFilePath: String? = nil,
        bitRate: Int = defaultBitRate,
        deleteWavAfterConversion: Bool = true
    ) -> ConversionResult {
        let wavURL = URL(fileURLWithPath: wavFilePath)
        
        // Check if WAV file exists
        guard FileManager.default.fileExists(atPath: wavFilePath) else {
            return .error(message: "WAV file not found: \(wavFilePath)")
        }
        
        // Determine output path - only replace the file extension, not substrings in directory names
        let outputPath: String
        if let customPath = m4aFilePath {
            outputPath = customPath
        } else {
            let url = URL(fileURLWithPath: wavFilePath)
            outputPath = url.deletingPathExtension().appendingPathExtension("m4a").path
        }
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Delete existing output file
        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        
        print("🎵 [WavToM4a] Converting: \(wavFilePath) -> \(outputPath)")
        
        // Create asset from WAV file
        let asset = AVAsset(url: wavURL)
        
        // Load audio tracks and format info
        // Use async load API on iOS 16+ to avoid deprecation warnings;
        // fall back to synchronous API on older versions.
        var audioTrack: AVAssetTrack?
        var assetDurationValue: CMTime = .zero
        
        if #available(iOS 16.0, *) {
            let semaphore = DispatchSemaphore(value: 0)
            var loadError: Error?
            
            Task {
                do {
                    let tracks = try await asset.loadTracks(withMediaType: .audio)
                    audioTrack = tracks.first
                    assetDurationValue = try await asset.load(.duration)
                } catch {
                    loadError = error
                }
                semaphore.signal()
            }
            semaphore.wait()
            
            if let error = loadError {
                return .error(message: "Failed to load asset: \(error.localizedDescription)")
            }
        } else {
            // Fallback for iOS < 16
            audioTrack = asset.tracks(withMediaType: .audio).first
            assetDurationValue = asset.duration
        }
        
        guard let track = audioTrack else {
            return .error(message: "No audio track found in WAV file")
        }
        
        // Get source format description
        let formatDescriptions: [CMFormatDescription]
        if #available(iOS 16.0, *) {
            let semaphore = DispatchSemaphore(value: 0)
            var loadedDescs: [CMFormatDescription] = []
            Task {
                do {
                    let descs = try await track.load(.formatDescriptions)
                    loadedDescs = descs as [CMFormatDescription]
                } catch {
                    // Will be handled below
                }
                semaphore.signal()
            }
            semaphore.wait()
            formatDescriptions = loadedDescs
        } else {
            formatDescriptions = track.formatDescriptions as? [CMFormatDescription] ?? []
        }
        
        guard let formatDescription = formatDescriptions.first else {
            return .error(message: "Could not get audio format description")
        }
        
        guard let sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return .error(message: "Could not parse audio stream basic description from format")
        }
        let sampleRate = sourceFormat.mSampleRate
        let channels = sourceFormat.mChannelsPerFrame
        
        print("🎵 [WavToM4a] Source: \(sampleRate)Hz, \(channels)ch")
        
        // Setup asset reader
        guard let reader = try? AVAssetReader(asset: asset) else {
            return .error(message: "Failed to create asset reader")
        }
        
        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: readerOutputSettings
        )
        
        guard reader.canAdd(readerOutput) else {
            return .error(message: "Cannot add reader output")
        }
        reader.add(readerOutput)
        
        // Setup asset writer
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .m4a) else {
            return .error(message: "Failed to create asset writer")
        }
        
        // AAC output settings
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = channels == 2 
            ? kAudioChannelLayoutTag_Stereo 
            : kAudioChannelLayoutTag_Mono
        let channelLayoutData = Data(bytes: &channelLayout, count: MemoryLayout<AudioChannelLayout>.size)
        
        let writerInputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate,
            AVChannelLayoutKey: channelLayoutData
        ]
        
        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: writerInputSettings
        )
        writerInput.expectsMediaDataInRealTime = false
        
        guard writer.canAdd(writerInput) else {
            return .error(message: "Cannot add writer input")
        }
        writer.add(writerInput)
        
        // Start reading and writing
        guard reader.startReading() else {
            return .error(message: "Failed to start reading: \(reader.error?.localizedDescription ?? "unknown")")
        }
        
        guard writer.startWriting() else {
            return .error(message: "Failed to start writing: \(writer.error?.localizedDescription ?? "unknown")")
        }
        
        writer.startSession(atSourceTime: .zero)
        
        // Process audio samples
        // Use userInitiated QoS to avoid priority inversion warning
        let queue = DispatchQueue(label: "com.nitrosound.wavtom4a", qos: .userInitiated)
        let semaphore = DispatchSemaphore(value: 0)
        var conversionError: String? = nil
        
        writerInput.requestMediaDataWhenReady(on: queue) {
            while writerInput.isReadyForMoreMediaData {
                if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                    writerInput.append(sampleBuffer)
                } else {
                    // No more samples
                    writerInput.markAsFinished()
                    
                    if reader.status == .failed {
                        conversionError = "Reader failed: \(reader.error?.localizedDescription ?? "unknown")"
                    }
                    
                    semaphore.signal()
                    return
                }
            }
        }
        
        // Wait for conversion to complete
        semaphore.wait()
        
        // Check for errors
        if let error = conversionError {
            writer.cancelWriting()
            return .error(message: error)
        }
        
        // Finish writing
        let finishSemaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            finishSemaphore.signal()
        }
        finishSemaphore.wait()
        
        // Check writer status
        if writer.status == .failed {
            return .error(message: "Writer failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
        
        // Get duration from source asset (already loaded above)
        let duration = assetDurationValue.seconds
        
        // Verify output file exists
        guard FileManager.default.fileExists(atPath: outputPath) else {
            return .error(message: "Output file was not created")
        }
        
        // Validate output file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("🎵 [WavToM4a] Conversion successful: \(fileSize) bytes, \(duration)s")
            
            if fileSize == 0 {
                return .error(message: "Output file is empty (0 bytes)")
            }
        } catch {
            print("🎵 [WavToM4a] Could not get file attributes: \(error)")
        }
        
        // Validate M4A duration matches source WAV duration
        if deleteWavAfterConversion && duration > 0 {
            let outputAsset = AVAsset(url: URL(fileURLWithPath: outputPath))
            let outputDuration: Double
            if #available(iOS 16.0, *) {
                let semaphore = DispatchSemaphore(value: 0)
                var dur: Double = 0
                Task {
                    dur = (try? await outputAsset.load(.duration).seconds) ?? 0
                    semaphore.signal()
                }
                semaphore.wait()
                outputDuration = dur
            } else {
                outputDuration = outputAsset.duration.seconds
            }
            let tolerance = max(duration * 0.1, 0.5) // 10% tolerance, minimum 0.5s
            
            let durationDiff: Double = Swift.abs(outputDuration - duration)
            if durationDiff > tolerance {
                print("🎵 [WavToM4a] Duration mismatch: source=\(duration)s, output=\(outputDuration)s, tolerance=\(tolerance)s. Keeping WAV file.")
                // Return success with M4A path but do NOT delete WAV
                return .success(outputPath: outputPath, duration: duration)
            }
        }
        
        // Validation passed - delete WAV file if requested
        if deleteWavAfterConversion {
            do {
                try FileManager.default.removeItem(atPath: wavFilePath)
                print("🎵 [WavToM4a] Deleted original WAV file")
            } catch {
                print("🎵 [WavToM4a] Failed to delete WAV file: \(error)")
            }
        }
        
        return .success(outputPath: outputPath, duration: duration)
    }
}
