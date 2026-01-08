# Fix: Preserving Recording State on Android

## Problem

When recording and a phone call comes in:

```
1. Recording normally
2. Phone call arrives → Recording auto-pauses ✅
3. Phone call ends → App returns to foreground
4. ❌ BUG: Recording state is lost, cannot resume
```

## Root Cause

### 1. MediaRecorder State Loss
When the app goes to background (due to phone call), Android may:
- Pause the MediaRecorder
- Or release it entirely if resources are needed

### 2. No State Tracking
The old code did not persist recording state:
- Did not know if it was recording or paused
- Did not know if resume was possible

### 3. No Validation Before Resume
When `resumeRecorder()` was called:
- Did not check if MediaRecorder was still valid
- Caused crashes or silent failures

## Solution Implemented

### 1. State Tracking in Foreground Service

```kotlin
class RecordingForegroundService : Service() {
    // Recording state
    private var isRecording: Boolean = false
    private var isPaused: Boolean = false
    
    // Time tracking for accurate position
    private var recordStartTime: Long = 0L
    private var pausedRecordTime: Long = 0L
}
```

### 2. Updated startRecording()

```kotlin
fun startRecording(...): Boolean {
    // Clean up any existing recording
    stopRecordingInternal()
    
    // Setup and start MediaRecorder
    mediaRecorder = MediaRecorder().apply {
        // ... config ...
        prepare()
        start()
    }
    
    // Update state
    recordStartTime = System.currentTimeMillis()
    pausedRecordTime = 0L
    isRecording = true
    isPaused = false
    
    return true
}
```

### 3. Improved pauseRecording()

```kotlin
fun pauseRecording(): Boolean {
    if (!isRecording || isPaused) return false
    
    return try {
        mediaRecorder?.pause()
        
        // Track elapsed recording time
        pausedRecordTime = System.currentTimeMillis() - recordStartTime
        isPaused = true
        isRecording = false
        
        true
    } catch (e: Exception) {
        false
    }
}
```

### 4. Improved resumeRecording()

```kotlin
fun resumeRecording(): Boolean {
    // Validate state before resume
    if (!isPaused) return false
    if (mediaRecorder == null) return false
    
    return try {
        mediaRecorder?.resume()
        
        // Restore time tracking
        recordStartTime = System.currentTimeMillis() - pausedRecordTime
        isPaused = false
        isRecording = true
        
        true
    } catch (e: Exception) {
        false
    }
}
```

### 5. Accurate Time Tracking

```kotlin
fun getCurrentRecordingTime(): Double {
    return if (isRecording) {
        (System.currentTimeMillis() - recordStartTime).toDouble()
    } else if (isPaused) {
        pausedRecordTime.toDouble()
    } else {
        0.0
    }
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
    if (isRecording || isPaused) {
        stopRecordTimer()
        
        mediaRecorder?.apply {
            try { stop() } catch (e: Exception) { }
            try { release() } catch (e: Exception) { }
        }
        mediaRecorder = null
        
        // Log saved file for debugging
        currentRecordingPath?.let { path ->
            val file = File(path)
            if (file.exists()) {
                Logger.d("Audio file saved: $path (${file.length()} bytes)")
            }
        }
        
        isRecording = false
        isPaused = false
    }
}
```

## Results

| Before Fix | After Fix |
|------------|-----------|
| ❌ Lost state during phone call | ✅ State preserved across interruptions |
| ❌ Resume failed after phone call | ✅ Resume works correctly |
| ❌ Unknown elapsed recording time | ✅ Accurate time tracking |
| ❌ Crash when MediaRecorder was released | ✅ Clear error returned |

## Testing Scenarios

### ✅ Scenario 1: Phone Call → Resume
```
Start recording → Call arrives → Pause → Call ends → Resume → OK
```

### ✅ Scenario 2: Phone Call → Stop
```
Start recording → Call arrives → Pause → Call ends → Stop → File saved OK
```

### ✅ Scenario 3: App Goes to Background
```
Start recording → App goes to background → App returns → State preserved
```

### ⚠️ Scenario 4: App Killed
```
Start recording → App killed by system → File saved (if onTaskRemoved fires)
                                        → File lost (if force stopped)
```

## Important Notes

### 1. MediaRecorder May Be Released
If Android needs resources, it may release the MediaRecorder. In this case:
- `resumeRecorder()` will return `false`
- User needs to start a new recording

### 2. Recorded Data Is Preserved
If recording is interrupted:
- Previously recorded data is still saved in the file
- User can stop to get the partial file (without resuming)

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
      console.log('Cannot resume, MediaRecorder was released by system');
    });
    
    // Option 2: Stop and get file
    stopRecorder().then((filePath) => {
      console.log('Saved:', filePath);
    });
  }
});
```
