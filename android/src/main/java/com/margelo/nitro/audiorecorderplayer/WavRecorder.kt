package com.margelo.nitro.audiorecorderplayer

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.log10

/**
 * WAV Recorder using AudioRecord for crash-resilient audio recording.
 * 
 * Advantages over MediaRecorder:
 * - WAV files are always playable even if recording is interrupted
 * - Data is written continuously, no buffering issues
 * - Header can be repaired/updated after crash
 * - Better control over recording process
 * 
 * WAV Format:
 * - 44 bytes header
 * - Raw PCM data follows
 * - Header contains data size which needs to be updated when recording stops
 */
class WavRecorder {
    private var audioRecord: AudioRecord? = null
    private var outputStream: FileOutputStream? = null
    private var recordingThread: Thread? = null
    
    private var filePath: String? = null
    @Volatile private var isRecording: Boolean = false
    @Volatile private var isPaused: Boolean = false
    
    // Audio settings
    private var sampleRate: Int = 44100
    private var channelConfig: Int = AudioFormat.CHANNEL_IN_MONO
    private var audioFormat: Int = AudioFormat.ENCODING_PCM_16BIT
    private var channelCount: Int = 1
    private var bitsPerSample: Int = 16
    
    // Recording stats
    private var totalBytesWritten: Long = 0L
    private var recordStartTime: Long = 0L
    private var pausedDuration: Long = 0L
    private var pauseStartTime: Long = 0L
    
    // Metering
    private var lastMaxAmplitude: Int = 0
    
    companion object {
        private const val WAV_HEADER_SIZE = 44
        private const val BUFFER_SIZE_FACTOR = 2
        
        // WAV header constants
        private const val RIFF = "RIFF"
        private const val WAVE = "WAVE"
        private const val FMT = "fmt "
        private const val DATA = "data"
        private const val PCM_FORMAT: Short = 1
        
        /**
         * Repair a WAV file by updating its header with correct data size.
         * Useful for recovering files after app crash.
         */
        fun repairWavFile(filePath: String): Boolean {
            return try {
                val file = File(filePath)
                if (!file.exists() || file.length() < WAV_HEADER_SIZE) {
                    return false
                }
                
                val dataSize = file.length() - WAV_HEADER_SIZE
                val fileSize = dataSize + WAV_HEADER_SIZE - 8
                
                // WAV format uses 32-bit sizes; files > 2GB will have truncated headers
                if (dataSize > Int.MAX_VALUE) {
                    Logger.w("[WavRecorder] WAV file exceeds 2GB ($dataSize bytes), header sizes will be truncated")
                }
                
                RandomAccessFile(file, "rw").use { raf ->
                    // Update RIFF chunk size at position 4
                    raf.seek(4)
                    raf.write(intToByteArray(fileSize.toInt()))
                    
                    // Update data chunk size at position 40
                    raf.seek(40)
                    raf.write(intToByteArray(dataSize.toInt()))
                }
                
                Logger.d("[WavRecorder] Repaired WAV file: $filePath (data size: $dataSize bytes)")
                true
            } catch (e: Exception) {
                Logger.e("[WavRecorder] Failed to repair WAV file: ${e.message}", e)
                false
            }
        }
        
        private fun intToByteArray(value: Int): ByteArray {
            return ByteBuffer.allocate(4)
                .order(ByteOrder.LITTLE_ENDIAN)
                .putInt(value)
                .array()
        }
    }
    
    /**
     * Start recording to the specified file path.
     * 
     * @param path Output file path (should end with .wav)
     * @param audioSource Audio source (e.g., MediaRecorder.AudioSource.MIC)
     * @param sampleRateHz Sample rate in Hz (e.g., 44100, 48000)
     * @param channels Number of channels (1 for mono, 2 for stereo)
     * @param bitsPerSample Bits per sample (16 recommended for compatibility)
     * @return true if recording started successfully
     */
    fun startRecording(
        path: String,
        audioSource: Int = MediaRecorder.AudioSource.MIC,
        sampleRateHz: Int = 44100,
        channels: Int = 1,
        bitsPerSample: Int = 16
    ): Boolean {
        try {
            // Stop any existing recording
            stopRecording()
            
            this.filePath = path
            this.sampleRate = sampleRateHz
            this.channelCount = channels
            this.bitsPerSample = bitsPerSample
            this.channelConfig = if (channels == 2) {
                AudioFormat.CHANNEL_IN_STEREO
            } else {
                AudioFormat.CHANNEL_IN_MONO
            }
            this.audioFormat = if (bitsPerSample == 8) {
                AudioFormat.ENCODING_PCM_8BIT
            } else {
                AudioFormat.ENCODING_PCM_16BIT
            }
            
            // Calculate buffer size
            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = minBufferSize * BUFFER_SIZE_FACTOR
            
            if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
                Logger.e("[WavRecorder] Invalid buffer size for audio settings")
                return false
            }
            
            // Create AudioRecord
            audioRecord = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioRecord.Builder()
                    .setAudioSource(audioSource)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(sampleRate)
                            .setChannelMask(channelConfig)
                            .setEncoding(audioFormat)
                            .build()
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                AudioRecord(
                    audioSource,
                    sampleRate,
                    channelConfig,
                    audioFormat,
                    bufferSize
                )
            }
            
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Logger.e("[WavRecorder] AudioRecord failed to initialize")
                audioRecord?.release()
                audioRecord = null
                return false
            }
            
            // Create output file and write WAV header
            val file = File(path)
            file.parentFile?.mkdirs()
            
            outputStream = FileOutputStream(file)
            writeWavHeader(outputStream!!, sampleRate, channelCount, bitsPerSample)
            
            // Reset stats
            totalBytesWritten = 0L
            recordStartTime = System.currentTimeMillis()
            pausedDuration = 0L
            lastMaxAmplitude = 0
            
            // Start recording
            isRecording = true
            isPaused = false
            audioRecord?.startRecording()
            
            // Start recording thread
            recordingThread = Thread {
                recordingLoop(bufferSize)
            }.apply {
                priority = Thread.MAX_PRIORITY
                start()
            }
            
            Logger.d("[WavRecorder] Recording started: $path (${sampleRate}Hz, ${channelCount}ch, ${bitsPerSample}bit)")
            return true
            
        } catch (e: Exception) {
            Logger.e("[WavRecorder] Failed to start recording: ${e.message}", e)
            cleanup()
            return false
        }
    }
    
    /**
     * Pause recording. Data written so far is preserved.
     */
    fun pauseRecording(): Boolean {
        if (!isRecording || isPaused) return false
        
        isPaused = true
        pauseStartTime = System.currentTimeMillis()
        Logger.d("[WavRecorder] Recording paused")
        return true
    }
    
    /**
     * Resume recording after pause.
     */
    fun resumeRecording(): Boolean {
        if (!isRecording || !isPaused) return false
        
        pausedDuration += System.currentTimeMillis() - pauseStartTime
        isPaused = false
        Logger.d("[WavRecorder] Recording resumed")
        return true
    }
    
    /**
     * Stop recording and finalize the WAV file.
     * This updates the WAV header with correct data size.
     * 
     * @return The path to the recorded file, or null if no recording
     */
    fun stopRecording(): String? {
        if (!isRecording && audioRecord == null) {
            return filePath
        }
        
        isRecording = false
        isPaused = false
        
        // Wait for recording thread to finish
        try {
            recordingThread?.join(1000)
        } catch (e: InterruptedException) {
            Logger.w("[WavRecorder] Interrupted while waiting for recording thread")
        }
        recordingThread = null
        
        // Stop and release AudioRecord
        try {
            audioRecord?.stop()
        } catch (e: Exception) {
            Logger.w("[WavRecorder] Error stopping AudioRecord: ${e.message}")
        }
        
        try {
            audioRecord?.release()
        } catch (e: Exception) {
            Logger.w("[WavRecorder] Error releasing AudioRecord: ${e.message}")
        }
        audioRecord = null
        
        // Close output stream
        try {
            outputStream?.flush()
            outputStream?.close()
        } catch (e: Exception) {
            Logger.w("[WavRecorder] Error closing output stream: ${e.message}")
        }
        outputStream = null
        
        // Update WAV header with correct data size
        filePath?.let { path ->
            updateWavHeader(path, totalBytesWritten)
        }
        
        Logger.d("[WavRecorder] Recording stopped: $filePath ($totalBytesWritten bytes)")
        
        return filePath
    }
    
    /**
     * Get current recording duration in milliseconds.
     */
    fun getCurrentDuration(): Long {
        if (!isRecording) return 0L
        
        val elapsed = System.currentTimeMillis() - recordStartTime
        val pauseTime = if (isPaused) {
            pausedDuration + (System.currentTimeMillis() - pauseStartTime)
        } else {
            pausedDuration
        }
        
        return elapsed - pauseTime
    }
    
    /**
     * Get the maximum amplitude since last call.
     * Used for audio level metering.
     * 
     * @return Maximum amplitude (0-32767) or 0 if not recording
     */
    fun getMaxAmplitude(): Int {
        val amplitude = lastMaxAmplitude
        lastMaxAmplitude = 0
        return amplitude
    }
    
    /**
     * Get metering value in decibels.
     * 
     * @return Decibel value (-160 to 0)
     */
    fun getMeteringDb(): Double {
        val amplitude = getMaxAmplitude()
        return if (amplitude > 0) {
            val normalizedAmplitude = amplitude.toDouble() / Short.MAX_VALUE
            val safeAmplitude = maxOf(normalizedAmplitude, 1e-10)
            val decibels = 20 * log10(safeAmplitude)
            maxOf(-160.0, minOf(0.0, decibels))
        } else {
            -160.0
        }
    }
    
    fun isCurrentlyRecording(): Boolean = isRecording
    
    fun isCurrentlyPaused(): Boolean = isPaused
    
    fun getRecordingPath(): String? = filePath
    
    /**
     * Finalize recording for app kill/crash scenarios.
     * This ensures the WAV header is updated so the file can be played.
     */
    fun finalizeOnKill() {
        if (!isRecording && audioRecord == null) {
            // Try to repair existing file if path is set
            filePath?.let { repairWavFile(it) }
            return
        }
        
        Logger.d("[WavRecorder] Finalizing recording on app kill...")
        
        // Signal the recording thread to stop (isRecording is @Volatile)
        isRecording = false
        isPaused = false
        
        // Wait briefly for the recording thread to finish its current write
        try {
            recordingThread?.join(500)
        } catch (e: InterruptedException) {
            Logger.w("[WavRecorder] Interrupted while waiting for recording thread on kill")
        }
        recordingThread = null
        
        // Stop AudioRecord
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Logger.w("[WavRecorder] Error stopping AudioRecord on kill: ${e.message}")
        }
        audioRecord = null
        
        // Close output stream
        try {
            outputStream?.flush()
            outputStream?.close()
        } catch (e: Exception) {
            Logger.w("[WavRecorder] Error closing stream on kill: ${e.message}")
        }
        outputStream = null
        
        // Update WAV header
        filePath?.let { path ->
            updateWavHeader(path, totalBytesWritten)
            Logger.d("[WavRecorder] WAV file finalized: $path ($totalBytesWritten bytes)")
        }
    }
    
    // ==================== Private Methods ====================
    
    private fun recordingLoop(bufferSize: Int) {
        val buffer = ByteArray(bufferSize)
        val shortBuffer = ShortArray(bufferSize / 2)
        
        while (isRecording) {
            if (isPaused) {
                // Sleep briefly while paused to avoid busy waiting
                try {
                    Thread.sleep(50)
                } catch (e: InterruptedException) {
                    break
                }
                continue
            }
            
            val bytesRead = audioRecord?.read(buffer, 0, bufferSize) ?: -1
            
            if (bytesRead > 0) {
                // Write to file
                try {
                    outputStream?.write(buffer, 0, bytesRead)
                    totalBytesWritten += bytesRead
                    
                    // Calculate max amplitude for metering
                    if (bitsPerSample == 16) {
                        ByteBuffer.wrap(buffer, 0, bytesRead)
                            .order(ByteOrder.LITTLE_ENDIAN)
                            .asShortBuffer()
                            .get(shortBuffer, 0, bytesRead / 2)
                        
                        var maxAmp = 0
                        for (i in 0 until bytesRead / 2) {
                            val amplitude = abs(shortBuffer[i].toInt())
                            if (amplitude > maxAmp) {
                                maxAmp = amplitude
                            }
                        }
                        if (maxAmp > lastMaxAmplitude) {
                            lastMaxAmplitude = maxAmp
                        }
                    }
                } catch (e: Exception) {
                    Logger.e("[WavRecorder] Error writing audio data: ${e.message}", e)
                    break
                }
            } else if (bytesRead < 0) {
                Logger.e("[WavRecorder] AudioRecord read error: $bytesRead")
                break
            }
        }
    }
    
    private fun writeWavHeader(
        out: FileOutputStream,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int
    ) {
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        
        // We write placeholder values for file size and data size
        // These will be updated when recording stops
        val header = ByteBuffer.allocate(WAV_HEADER_SIZE)
            .order(ByteOrder.LITTLE_ENDIAN)
            
        // RIFF header
        header.put(RIFF.toByteArray())      // ChunkID
        header.putInt(0)                     // ChunkSize (placeholder)
        header.put(WAVE.toByteArray())       // Format
        
        // fmt subchunk
        header.put(FMT.toByteArray())        // Subchunk1ID
        header.putInt(16)                    // Subchunk1Size (16 for PCM)
        header.putShort(PCM_FORMAT)          // AudioFormat (1 = PCM)
        header.putShort(channels.toShort())  // NumChannels
        header.putInt(sampleRate)            // SampleRate
        header.putInt(byteRate)              // ByteRate
        header.putShort(blockAlign.toShort()) // BlockAlign
        header.putShort(bitsPerSample.toShort()) // BitsPerSample
        
        // data subchunk
        header.put(DATA.toByteArray())       // Subchunk2ID
        header.putInt(0)                     // Subchunk2Size (placeholder)
        
        out.write(header.array())
    }
    
    private fun updateWavHeader(path: String, dataSize: Long) {
        try {
            // WAV format uses 32-bit sizes; files > 2GB will have truncated headers
            if (dataSize > Int.MAX_VALUE) {
                Logger.w("[WavRecorder] Recording exceeds 2GB ($dataSize bytes), header sizes will be truncated")
            }
            
            RandomAccessFile(path, "rw").use { raf ->
                val fileSize = dataSize + WAV_HEADER_SIZE - 8
                
                // Update RIFF chunk size at position 4
                raf.seek(4)
                raf.write(intToByteArray(fileSize.toInt()))
                
                // Update data chunk size at position 40
                raf.seek(40)
                raf.write(intToByteArray(dataSize.toInt()))
                
                Logger.d("[WavRecorder] Updated WAV header: file=${fileSize + 8} bytes, data=$dataSize bytes")
            }
        } catch (e: Exception) {
            Logger.e("[WavRecorder] Failed to update WAV header: ${e.message}", e)
        }
    }
    
    private fun cleanup() {
        isRecording = false
        isPaused = false
        
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            // Ignore
        }
        audioRecord = null
        
        try {
            outputStream?.close()
        } catch (e: Exception) {
            // Ignore
        }
        outputStream = null
        
        recordingThread = null
    }
}
