# Fix: Preserving Recording State on Android

## Problem

When recording and a phone call comes in:

```text
1. Recording normally
2. Phone call arrives → Recording auto-pauses ✅
3. Phone call ends → App returns to foreground
4. ❌ BUG: Recording state is lost, cannot resume
```

## Root Cause

### 1. Recorder State Loss

When the app goes to background (due to phone call), Android may:
- Pause the recorder
- Or release it entirely if resources are needed

### 2. No State Tracking

The old code did not persist recording state:
- Did not know if it was recording or paused
- Did not know if resume was possible

### 3. No Validation Before Resume

When `resumeRecorder()` was called:
- Did not check if WavRecorder was still valid
- Caused crashes or silent failures

## Solution Implemented

### 1. State Tracking in Foreground Service

```kotlin
class RecordingForegroundService : Service() {
    private var wavRecorder: WavRecorder? = null

    // Time tracking via WavRecorder
    fun getCurrentRecordingTime(): Double {
        return wavRecorder?.getCurrentDuration()?.toDouble() ?: 0.0
    }
}
```

### 2. Updated startRecording()

```kotlin
fun startRecording(...): Boolean {
    // Clean up any existing recording
    stopRecordingInternal()

    // Setup and start WavRecorder (crash-resilient WAV format)
    wavRecorder = WavRecorder()
    val success = wavRecorder!!.startRecording(
        path = wavFilePath,
        audioSource = audioSource,
        sampleRateHz = samplingRate ?: 44100,
        channels = channels ?: 1,
        bitsPerSample = 16
    )

    // Acquire wake lock while recording
    acquireWakeLock()

    return success
}
```

### 3. Improved pauseRecording()

```kotlin
fun pauseRecording(): Boolean {
    val recorder = wavRecorder ?: return false

    return try {
        val success = recorder.pauseRecording()
        if (success) {
            stopRecordTimer()
            releaseWakeLock()
            updateNotification("Recording paused")
        }
        success
    } catch (e: Exception) {
        Logger.e("[ForegroundService] Error pausing: ${e.message}", e)
        false
    }
}
```

### 4. Improved resumeRecording()

```kotlin
fun resumeRecording(): Boolean {
    val recorder = wavRecorder ?: return false

    return try {
        val success = recorder.resumeRecording()
        if (success) {
            acquireWakeLock()
            startRecordTimer(subscriptionDurationMs)
            updateNotification("Recording in progress...")
        }
        success
    } catch (e: Exception) {
        Logger.e("[ForegroundService] Error resuming: ${e.message}", e)
        false
    }
}
```

### 5. Accurate Time Tracking

```kotlin
// In WavRecorder
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
```

### 6. App Kill Handling

```kotlin
override fun onTaskRemoved(rootIntent: Intent?) {
    // User swipe-killed the app
    finalizeRecordingOnKill()
    super.onTaskRemoved(rootIntent)
    stopSelf()
}

private fun finalizeRecordingOnKill() {
    stopRecordTimer()

    // WavRecorder handles its own finalization and header update
    wavRecorder?.finalizeOnKill()
    wavRecorder = null

    // Release wake lock
    releaseWakeLock()
}
```

## Results

| Before Fix | After Fix |
|------------|-----------|
| Lost state during phone call | State preserved across interruptions |
| Resume failed after phone call | Resume works correctly |
| Unknown elapsed recording time | Accurate time tracking |
| Crash when recorder was released | Clear error returned |
| M4A file corrupted on crash | WAV file always recoverable |

## Testing Scenarios

### Scenario 1: Phone Call -> Resume

```text
Start recording → Call arrives → Pause → Call ends → Resume → OK
```

### Scenario 2: Phone Call -> Stop

```text
Start recording → Call arrives → Pause → Call ends → Stop → File saved OK
```

### Scenario 3: App Goes to Background

```text
Start recording → App goes to background → App returns → State preserved
```

### Scenario 4: App Killed

```text
Start recording → App killed by system → WAV file saved (onTaskRemoved)
                                        → File recoverable via restorePendingRecordings()
```

## Important Notes

### 1. WAV Format for Crash Resilience

Unlike M4A, WAV files are always playable even if recording is interrupted:
- PCM data is written directly to disk
- WAV header can be repaired after crash via `repairWavFile()`
- Recovered WAV files are converted to M4A via `WavToM4aConverter`

### 2. Recorded Data Is Preserved

If recording is interrupted:
- Previously recorded data is still saved in the WAV file
- User can stop to get the partial file (without resuming)
- Use `restorePendingRecordings()` after app restart to recover files

### 3. Callbacks Always Have Accurate Time

When `recordBackListener` fires:
- `currentPosition`: Actual elapsed recording time in ms
- `isRecording`: `false` when paused

## Usage Example

```typescript
const { resumeRecorder, stopRecorder, addRecordBackListener } = useSound();

addRecordBackListener((meta) => {
  if (!meta.isRecording) {
    console.log('Paused at:', meta.currentPosition, 'ms');

    // Option 1: Resume recording
    resumeRecorder().catch(() => {
      console.log('Cannot resume, recorder was released by system');
    });

    // Option 2: Stop and get file
    stopRecorder().then((filePath) => {
      console.log('Saved:', filePath);
    });
  }
});
```
