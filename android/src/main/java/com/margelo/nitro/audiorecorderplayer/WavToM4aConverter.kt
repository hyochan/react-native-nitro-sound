package com.margelo.nitro.audiorecorderplayer

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import java.io.File
import java.io.FileInputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Converts WAV audio files to M4A (AAC) format.
 * 
 * Uses MediaCodec for AAC encoding and MediaMuxer for M4A container.
 * This allows recording in crash-resilient WAV format, then converting
 * to smaller M4A format after successful recording.
 */
object WavToM4aConverter {
    
    private const val CODEC_TIMEOUT_US = 10000L
    private const val DEFAULT_BIT_RATE = 128000
    private const val AAC_PROFILE = MediaCodecInfo.CodecProfileLevel.AACObjectLC
    
    /**
     * WAV file header information
     */
    data class WavHeader(
        val audioFormat: Int,
        val numChannels: Int,
        val sampleRate: Int,
        val byteRate: Int,
        val blockAlign: Int,
        val bitsPerSample: Int,
        val dataSize: Long,
        val dataOffset: Long
    )
    
    /**
     * Result of conversion operation
     */
    sealed class ConversionResult {
        data class Success(val outputPath: String, val duration: Long) : ConversionResult()
        data class Error(val message: String, val exception: Exception? = null) : ConversionResult()
    }
    
    /**
     * Convert a WAV file to M4A format.
     * 
     * @param wavFilePath Path to the input WAV file
     * @param m4aFilePath Optional output path. If null, will use same path with .m4a extension
     * @param bitRate Target bit rate for AAC encoding (default: 128kbps)
     * @param deleteWavAfterConversion Whether to delete the WAV file after successful conversion
     * @return ConversionResult indicating success or failure
     */
    suspend fun convert(
        wavFilePath: String,
        m4aFilePath: String? = null,
        bitRate: Int = DEFAULT_BIT_RATE,
        deleteWavAfterConversion: Boolean = true
    ): ConversionResult = withContext(Dispatchers.IO) {
        try {
            val wavFile = File(wavFilePath)
            if (!wavFile.exists()) {
                return@withContext ConversionResult.Error("WAV file not found: $wavFilePath")
            }
            
            // Parse WAV header
            val wavHeader = parseWavHeader(wavFilePath)
                ?: return@withContext ConversionResult.Error("Invalid WAV file format")
            
            // Validate WAV format
            if (wavHeader.audioFormat != 1) {
                return@withContext ConversionResult.Error("Only PCM WAV files are supported")
            }
            
            if (wavHeader.bitsPerSample != 16) {
                return@withContext ConversionResult.Error("Only 16-bit WAV files are supported")
            }
            
            // Determine output path
            val outputPath = m4aFilePath ?: wavFilePath.replace(".wav", ".m4a", ignoreCase = true)
            val outputFile = File(outputPath)
            
            // Delete existing output file
            if (outputFile.exists()) {
                outputFile.delete()
            }
            
            Logger.d("[WavToM4a] Converting: $wavFilePath -> $outputPath")
            Logger.d("[WavToM4a] WAV info: ${wavHeader.sampleRate}Hz, ${wavHeader.numChannels}ch, ${wavHeader.bitsPerSample}bit")
            
            // Perform conversion
            val success = encodeToM4a(
                wavFilePath = wavFilePath,
                m4aFilePath = outputPath,
                wavHeader = wavHeader,
                bitRate = bitRate
            )
            
            if (!success) {
                // Clean up failed output
                outputFile.delete()
                return@withContext ConversionResult.Error("Encoding failed")
            }
            
            // Verify output file
            if (!outputFile.exists() || outputFile.length() == 0L) {
                return@withContext ConversionResult.Error("Output file is empty or missing")
            }
            
            // Calculate duration in milliseconds
            val durationMs = (wavHeader.dataSize * 1000L) / wavHeader.byteRate
            
            Logger.d("[WavToM4a] Conversion successful: ${outputFile.length()} bytes, ${durationMs}ms")
            
            // Validate output file size is reasonable compared to input
            val inputSize = wavFile.length()
            val outputSize = outputFile.length()
            if (inputSize > 0 && outputSize < inputSize * 0.05) {
                // Output is suspiciously small (less than 5% of input)
                Logger.w("[WavToM4a] Output file too small: input=${inputSize}, output=${outputSize}. Keeping WAV file.")
                return@withContext ConversionResult.Success(outputPath, durationMs)
            }
            
            // Delete WAV file if requested (only after validation)
            if (deleteWavAfterConversion) {
                try {
                    wavFile.delete()
                    Logger.d("[WavToM4a] Deleted original WAV file")
                } catch (e: Exception) {
                    Logger.w("[WavToM4a] Failed to delete WAV file: ${e.message}")
                }
            }
            
            ConversionResult.Success(outputPath, durationMs)
            
        } catch (e: Exception) {
            Logger.e("[WavToM4a] Conversion error: ${e.message}", e)
            ConversionResult.Error("Conversion failed: ${e.message}", e)
        }
    }
    
    /**
     * Synchronous version of convert for use in non-coroutine contexts
     */
    fun convertSync(
        wavFilePath: String,
        m4aFilePath: String? = null,
        bitRate: Int = DEFAULT_BIT_RATE,
        deleteWavAfterConversion: Boolean = true
    ): ConversionResult {
        return try {
            val wavFile = File(wavFilePath)
            if (!wavFile.exists()) {
                return ConversionResult.Error("WAV file not found: $wavFilePath")
            }
            
            val wavHeader = parseWavHeader(wavFilePath)
                ?: return ConversionResult.Error("Invalid WAV file format")
            
            if (wavHeader.audioFormat != 1) {
                return ConversionResult.Error("Only PCM WAV files are supported")
            }
            
            if (wavHeader.bitsPerSample != 16) {
                return ConversionResult.Error("Only 16-bit WAV files are supported")
            }
            
            val outputPath = m4aFilePath ?: wavFilePath.replace(".wav", ".m4a", ignoreCase = true)
            val outputFile = File(outputPath)
            
            if (outputFile.exists()) {
                outputFile.delete()
            }
            
            Logger.d("[WavToM4a] Converting: $wavFilePath -> $outputPath")
            
            val success = encodeToM4a(
                wavFilePath = wavFilePath,
                m4aFilePath = outputPath,
                wavHeader = wavHeader,
                bitRate = bitRate
            )
            
            if (!success) {
                outputFile.delete()
                return ConversionResult.Error("Encoding failed")
            }
            
            if (!outputFile.exists() || outputFile.length() == 0L) {
                return ConversionResult.Error("Output file is empty or missing")
            }
            
            val durationMs = (wavHeader.dataSize * 1000L) / wavHeader.byteRate
            
            // Validate output file size before deleting WAV
            val inputSize = wavFile.length()
            val outputSize = outputFile.length()
            if (deleteWavAfterConversion && inputSize > 0 && outputSize < inputSize * 0.05) {
                Logger.w("[WavToM4a] Output file too small: input=${inputSize}, output=${outputSize}. Keeping WAV file.")
                return ConversionResult.Success(outputPath, durationMs)
            }
            
            if (deleteWavAfterConversion) {
                try {
                    wavFile.delete()
                } catch (e: Exception) {
                    Logger.w("[WavToM4a] Failed to delete WAV file: ${e.message}")
                }
            }
            
            ConversionResult.Success(outputPath, durationMs)
            
        } catch (e: Exception) {
            Logger.e("[WavToM4a] Conversion error: ${e.message}", e)
            ConversionResult.Error("Conversion failed: ${e.message}", e)
        }
    }
    
    /**
     * Parse WAV file header to extract audio parameters
     */
    private fun parseWavHeader(filePath: String): WavHeader? {
        return try {
            RandomAccessFile(filePath, "r").use { raf ->
                val header = ByteArray(44)
                raf.read(header)
                
                val buffer = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                
                // Verify RIFF header
                val riff = String(header, 0, 4)
                if (riff != "RIFF") {
                    Logger.e("[WavToM4a] Invalid RIFF header: $riff")
                    return null
                }
                
                // Verify WAVE format
                val wave = String(header, 8, 4)
                if (wave != "WAVE") {
                    Logger.e("[WavToM4a] Invalid WAVE format: $wave")
                    return null
                }
                
                // Verify fmt chunk
                val fmt = String(header, 12, 4)
                if (fmt != "fmt ") {
                    Logger.e("[WavToM4a] Invalid fmt chunk: $fmt")
                    return null
                }
                
                // Parse audio format info
                buffer.position(20)
                val audioFormat = buffer.short.toInt() and 0xFFFF
                val numChannels = buffer.short.toInt() and 0xFFFF
                val sampleRate = buffer.int
                val byteRate = buffer.int
                val blockAlign = buffer.short.toInt() and 0xFFFF
                val bitsPerSample = buffer.short.toInt() and 0xFFFF
                
                // Find data chunk (might not be at position 36)
                raf.seek(12)
                var dataOffset = 12L
                var dataSize = 0L
                
                while (raf.filePointer < raf.length() - 8) {
                    val chunkId = ByteArray(4)
                    raf.read(chunkId)
                    val chunkIdStr = String(chunkId)
                    
                    val chunkSizeBytes = ByteArray(4)
                    raf.read(chunkSizeBytes)
                    val chunkSize = ByteBuffer.wrap(chunkSizeBytes)
                        .order(ByteOrder.LITTLE_ENDIAN)
                        .int.toLong() and 0xFFFFFFFFL
                    
                    if (chunkIdStr == "data") {
                        dataOffset = raf.filePointer
                        dataSize = chunkSize
                        break
                    } else {
                        // Skip this chunk
                        raf.seek(raf.filePointer + chunkSize)
                    }
                }
                
                if (dataSize == 0L) {
                    // Fallback: assume data starts at offset 44
                    dataOffset = 44L
                    dataSize = raf.length() - 44
                }
                
                WavHeader(
                    audioFormat = audioFormat,
                    numChannels = numChannels,
                    sampleRate = sampleRate,
                    byteRate = byteRate,
                    blockAlign = blockAlign,
                    bitsPerSample = bitsPerSample,
                    dataSize = dataSize,
                    dataOffset = dataOffset
                )
            }
        } catch (e: Exception) {
            Logger.e("[WavToM4a] Error parsing WAV header: ${e.message}", e)
            null
        }
    }
    
    /**
     * Encode PCM data from WAV file to AAC and mux into M4A container
     */
    private fun encodeToM4a(
        wavFilePath: String,
        m4aFilePath: String,
        wavHeader: WavHeader,
        bitRate: Int
    ): Boolean {
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var inputStream: FileInputStream? = null
        var muxerStarted = false
        var trackIndex = -1
        
        try {
            // Create AAC encoder
            val mediaFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                wavHeader.sampleRate,
                wavHeader.numChannels
            ).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, AAC_PROFILE)
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }
            
            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(mediaFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            
            // Create muxer
            muxer = MediaMuxer(m4aFilePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            
            // Open WAV file for reading
            inputStream = FileInputStream(wavFilePath)
            inputStream.skip(wavHeader.dataOffset)
            
            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            var presentationTimeUs = 0L
            
            // Calculate bytes per sample for timing
            val bytesPerSample = wavHeader.numChannels * (wavHeader.bitsPerSample / 8)
            val samplesPerSecond = wavHeader.sampleRate.toLong()
            
            val inputBuffer = ByteArray(4096)
            var totalBytesRead = 0L
            
            while (!outputDone) {
                // Feed input
                if (!inputDone) {
                    val inputBufferIndex = encoder.dequeueInputBuffer(CODEC_TIMEOUT_US)
                    if (inputBufferIndex >= 0) {
                        val codecInputBuffer = encoder.getInputBuffer(inputBufferIndex)
                        codecInputBuffer?.clear()
                        
                        val bytesToRead = minOf(inputBuffer.size, codecInputBuffer?.remaining() ?: 0)
                        val bytesRead = inputStream.read(inputBuffer, 0, bytesToRead)
                        
                        if (bytesRead <= 0 || totalBytesRead >= wavHeader.dataSize) {
                            encoder.queueInputBuffer(
                                inputBufferIndex,
                                0,
                                0,
                                presentationTimeUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            codecInputBuffer?.put(inputBuffer, 0, bytesRead)
                            totalBytesRead += bytesRead
                            
                            // Calculate presentation time
                            val samplesRead = totalBytesRead / bytesPerSample
                            presentationTimeUs = (samplesRead * 1000000L) / samplesPerSecond
                            
                            encoder.queueInputBuffer(
                                inputBufferIndex,
                                0,
                                bytesRead,
                                presentationTimeUs,
                                0
                            )
                        }
                    }
                }
                
                // Get output
                val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, CODEC_TIMEOUT_US)
                
                when {
                    outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = encoder.outputFormat
                        trackIndex = muxer.addTrack(outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outputBufferIndex >= 0 -> {
                        val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                        
                        if (outputBuffer != null && bufferInfo.size > 0 && muxerStarted) {
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                        }
                        
                        encoder.releaseOutputBuffer(outputBufferIndex, false)
                        
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
            
            return true
            
        } catch (e: Exception) {
            Logger.e("[WavToM4a] Encoding error: ${e.message}", e)
            return false
        } finally {
            try {
                inputStream?.close()
            } catch (e: Exception) { }
            
            try {
                encoder?.stop()
                encoder?.release()
            } catch (e: Exception) { }
            
            try {
                if (muxerStarted) {
                    muxer?.stop()
                }
                muxer?.release()
            } catch (e: Exception) { }
        }
    }
}
