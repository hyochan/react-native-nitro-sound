# Recording Interruption Handling & Recovery Guide

## Table of Contents

1. [Overview](#1-overview)
2. [Interruption Scenarios](#2-interruption-scenarios)
3. [How the Library Handles Interruptions](#3-how-the-library-handles-interruptions)
4. [M4A File Structure & Data Loss](#4-m4a-file-structure--data-loss)
5. [Crash-Resilient Recording (WAV)](#5-crash-resilient-recording-wav)
6. [Restore Mechanism](#6-restore-mechanism)
7. [Usage Guide](#7-usage-guide)
8. [FAQ](#8-faq)
9. [References](#9-references)

---

## 1. Overview

`react-native-nitro-sound` supports audio recording on both iOS and Android with the following features:

- ✅ Foreground and background recording
- ✅ Automatic pause on incoming phone calls
- ✅ Automatic pause when opening video/audio apps
- ✅ Graceful handling when user swipe-kills the app
- ✅ Foreground Service on Android (recording with screen off)
- ✅ **Crash-resilient WAV recording mode**
- ✅ **Restore mechanism for recovering interrupted recordings**

---

## 2. Interruption Scenarios

### Summary Table

| Scenario | iOS | Android | Status |
|----------|-----|---------|--------|
| Incoming phone call | ✅ Stop & Save | ✅ Pause | Handled |
| Open video/YouTube | ✅ Stop & Save | ✅ Pause | Handled |
| Open music/podcast app | ✅ Stop & Save | ✅ Pause | Handled |
| Google Assistant / Siri | ✅ Stop & Save | ✅ Pause | Handled |
| User swipe-kill app | ✅ Stop & Save | ✅ Stop & Save | Handled |
| App crash | ✅ WAV recoverable | ✅ WAV recoverable | **Recoverable** |
| Sudden power off | ✅ WAV recoverable | ✅ WAV recoverable | **Recoverable** |
| Battery dies suddenly | ✅ WAV recoverable | ✅ WAV recoverable | **Recoverable** |
| Force stop from Settings | ✅ WAV recoverable | ✅ WAV recoverable | **Recoverable** |

> **Note:** Scenarios marked "Recoverable" require using the **WAV recording mode** and calling `restorePendingRecordings()` on app launch. See [Section 6](#6-restore-mechanism) for details.

---

## 3. How the Library Handles Interruptions

### 3.1 iOS - AVAudioSession Interruption

**Mechanism:** Observes `AVAudioSession.interruptionNotification`

```swift
// Register observer
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleAudioSessionInterruption),
    name: AVAudioSession.interruptionNotification,
    object: nil
)

// Handle interruption
switch type {
case .began:
    // Interruption started (phone call, video, etc.)
    // → Stop recording and save file
    recorder.stop()
    
case .ended:
    // Interruption ended
    // → Do NOT auto-resume (let user decide)
}
```

**Behavior on iOS:**
- On interruption → Recording is **STOPPED completely** (not paused)
- Audio file is saved at that point
- User needs to call `startRecorder()` to begin a new recording
- Callback fires with `isRecording: false` and `currentPosition` in milliseconds

### 3.2 Android - Audio Focus Management

**Mechanism:** Uses `AudioFocusRequest` (API 26+) or `AudioManager.requestAudioFocus()` (legacy)

```kotlin
// Create Audio Focus Request (Android 8.0+)
AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
    .setAudioAttributes(audioAttributes)
    .setWillPauseWhenDucked(true) // Important: pause even when other apps "duck"
    .setOnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // Lost audio focus → Pause recording
                service.pauseRecording()
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                // Regained focus → Do NOT auto-resume
            }
        }
    }
    .build()
```

**Behavior on Android:**
- On interruption → Recording is **PAUSED**
- User can call `resumeRecorder()` to continue
- Or call `stopRecorder()` to finalize and save file
- Callback fires with `isRecording: false` and actual `currentPosition`

### 3.3 Foreground Service (Android)

The library uses a Foreground Service to:
- Continue recording when the screen is off
- Continue recording when the app is in the background
- Show "Recording in progress" notification
- Handle app kill via `onTaskRemoved()`

```kotlin
class RecordingForegroundService : Service() {
    // WakeLock to keep CPU running
    private var wakeLock: PowerManager.WakeLock? = null
    
    // Handle user swipe-kill
    override fun onTaskRemoved(rootIntent: Intent?) {
        finalizeRecordingOnKill()  // Save file before being killed
        super.onTaskRemoved(rootIntent)
        stopSelf()
    }
}
```

---

## 4. M4A File Structure & Data Loss

### 4.1 M4A File Structure

**M4A = MPEG-4 Audio Container + AAC Codec**

```text
┌─────────────────────────────────────────┐
│  ftyp (File Type) - 20-32 bytes         │  ← Written at start
├─────────────────────────────────────────┤
│  mdat (Media Data)                      │  ← Audio data, written continuously
│  ├─ AAC Frame 1                         │
│  ├─ AAC Frame 2                         │
│  ├─ ...                                 │
│  └─ AAC Frame N                         │
├─────────────────────────────────────────┤
│  moov (Metadata/Index)                  │  ← ONLY written when stop() is called!
│  ├─ Duration                            │
│  ├─ Sample rate                         │
│  ├─ Channels                            │
│  └─ Frame positions                     │
└─────────────────────────────────────────┘
```

### 4.2 Why M4A Files Get Corrupted

The `moov` atom contains the "map" of the audio data. Without it, players cannot:
- Know the file duration
- Locate individual frames
- Read codec parameters (sample rate, channels)

**If `stop()` is never called** → No `moov` → File is unplayable!

This happens when:
- Sudden power off (OS sends no callback)
- Battery dies suddenly (OS sends no callback)
- Force stop from Settings (OS kills process immediately)

---

## 5. Crash-Resilient Recording (WAV)

### 5.1 How WAV Solves the Problem

The library includes a **WavRecorder** that uses `AudioRecord` (Android) and `AVAudioEngine` (iOS) to record in WAV format:

```text
WAV File Structure:
┌─────────────────────────────────┐
│  RIFF Header (44 bytes)         │  ← Written FIRST (header at top)
│  - "RIFF"                       │
│  - File size (placeholder)      │
│  - "WAVE"                       │
│  - Format info (sample rate,    │
│    channels, bit depth)         │
│  - Data size (placeholder)      │
├─────────────────────────────────┤
│  PCM Audio Data                 │  ← Written continuously in real-time
│  - Sample 1                     │
│  - Sample 2                     │
│  - ...                          │
│  - Sample N                     │
└─────────────────────────────────┘
```

**Key difference from M4A:**
- Header is at the **beginning** of the file (not the end)
- PCM data is raw, uncompressed audio (no decoding needed)
- Even if the file size in the header is wrong, players can still read the audio data
- The library can **repair** the header after a crash

### 5.2 What Happens on Crash

```text
Normal stop:
┌────────────────┐ ┌──────────────────────┐
│ Header (fixed) │ │     Audio Data       │  ← Complete file ✅
└────────────────┘ └──────────────────────┘

After crash/power off:
┌────────────────┐ ┌──────────────────────┐
│ Header (wrong  │ │     Audio Data       │  ← Data is intact!
│  size fields)  │ │     (still valid)    │
└────────────────┘ └──────────────────────┘

After restore (header repair):
┌────────────────┐ ┌──────────────────────┐
│ Header (fixed) │ │     Audio Data       │  ← Fully playable ✅
└────────────────┘ └──────────────────────┘
```

**Result:** Maximum data loss is ~1-2 seconds (unflushed buffer), instead of 100%.

### 5.3 Comparison

| Aspect | M4A (default) | WAV (crash-resilient) |
|--------|---------------|----------------------|
| File size | ~1 MB/min | ~10 MB/min |
| Metadata position | End of file | Beginning of file |
| Sudden power off | ❌ 100% loss | ✅ ~1-2s loss |
| Force stop | ❌ 100% loss | ✅ ~1-2s loss |
| Battery death | ❌ 100% loss | ✅ ~1-2s loss |
| Recoverable | ❌ No | ✅ Yes |
| Quality | Lossy (AAC) | Lossless (PCM) |

---

## 6. Restore Mechanism

### 6.1 How It Works

The library provides two recovery methods:

1. **`restorePendingRecordings(directory?)`** - Scans a directory for incomplete WAV files, repairs their headers, converts them to M4A, and returns the results.

2. **`restoreRecording(wavFilePath)`** - Restores a single WAV file by repairing its header and converting it to M4A.

### 6.2 Recovery Flow

```text
┌──────────────────────────────────────────────────────────────────┐
│                        RECORDING FLOW                            │
│                                                                  │
│  startRecorder(uri)  ──────────►  WAV file on disk               │
│       │                           (crash-resilient)              │
│       │                                                          │
│  ┌────▼─────────────────────────────────────────────────────┐    │
│  │  Normal: stopRecorder()                                  │    │
│  │  → WAV header updated                                    │    │
│  │  → Converted to M4A                                      │    │
│  │  → Returns M4A path ✅                                    │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Crash/Power Off: WAV file left on disk                  │    │
│  │  → Header has wrong size (but data is intact)            │    │
│  │                                                          │    │
│  │  On next app launch:                                     │    │
│  │  restorePendingRecordings(directory)                      │    │
│  │  → Scans for .wav files                                  │    │
│  │  → Repairs WAV headers (updates size fields)             │    │
│  │  → Converts WAV to M4A                                   │    │
│  │  → Deletes original WAV file                             │    │
│  │  → Returns array of RestoredRecording ✅                  │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### 6.3 RestoredRecording Interface

```typescript
interface RestoredRecording {
  /** Path to the restored M4A file */
  uri: string;
  /** Duration in milliseconds */
  duration: number;
  /** Original WAV file path (before conversion) */
  originalPath: string;
}
```

### 6.4 Usage Examples

#### Restore all pending recordings on app launch

```typescript
import { useSound } from 'react-native-nitro-sound';

function App() {
  const sound = useSound();

  useEffect(() => {
    restoreInterruptedRecordings();
  }, []);

  async function restoreInterruptedRecordings() {
    try {
      // Scan default recording directory for incomplete WAV files
      const restored = await sound.restorePendingRecordings();

      if (restored.length > 0) {
        console.log(`Recovered ${restored.length} recording(s):`);

        for (const recording of restored) {
          console.log(`  - URI: ${recording.uri}`);
          console.log(`    Duration: ${recording.duration}ms`);
          console.log(`    Original: ${recording.originalPath}`);

          // Update your database/state with the recovered file
          await saveRecordingToDatabase(recording.uri, recording.duration);
        }
      }
    } catch (error) {
      console.error('Failed to restore recordings:', error);
    }
  }
}
```

#### Restore all pending recordings from a specific directory

```typescript
// Scan a specific directory
const restored = await sound.restorePendingRecordings('/path/to/recordings');
```

#### Restore a single WAV file

```typescript
// If you know the exact WAV file path
const recording = await sound.restoreRecording('/path/to/recording.wav');
console.log('Restored:', recording.uri);        // M4A file path
console.log('Duration:', recording.duration);    // Duration in ms
console.log('Original:', recording.originalPath); // Original WAV path
```

#### Complete recording flow with restore

```typescript
import { useSound } from 'react-native-nitro-sound';

function RecordingScreen() {
  const sound = useSound();
  const [recordingPath, setRecordingPath] = useState<string | null>(null);

  // 1. On app launch: restore any interrupted recordings
  useEffect(() => {
    sound.restorePendingRecordings()
      .then((restored) => {
        restored.forEach((r) => {
          // Handle recovered recordings (e.g., show in UI, upload, etc.)
          console.log('Recovered recording:', r.uri);
        });
      })
      .catch(console.error);
  }, []);

  // 2. Start recording (WAV file will be saved to disk continuously)
  const handleStart = async () => {
    try {
      const uri = await sound.startRecorder('/path/to/recording.wav');
      setRecordingPath(uri);
    } catch (error) {
      console.error('Start failed:', error);
    }
  };

  // 3. Listen for interruptions
  useEffect(() => {
    sound.addRecordBackListener((meta) => {
      if (!meta.isRecording) {
        // Recording was interrupted (call, video, etc.)
        console.log('Interrupted at:', meta.currentPosition, 'ms');
      }
    });

    return () => sound.removeRecordBackListener();
  }, []);

  // 4. Stop recording (normal flow)
  const handleStop = async () => {
    try {
      const filePath = await sound.stopRecorder();
      console.log('Saved:', filePath);
    } catch (error) {
      console.error('Stop failed:', error);
    }
  };
}
```

---

## 7. Usage Guide

### 7.1 Handling Interruption Callbacks

```typescript
sound.addRecordBackListener((meta) => {
  if (!meta.isRecording) {
    // Recording was paused (Android) or stopped (iOS)
    // Possible reasons: phone call, video, user action, app kill
    console.log('Recording interrupted at:', meta.currentPosition, 'ms');

    // Update your UI
    setRecordingState('paused');
  }
});
```

### 7.2 Resume After Interruption (Android only)

```typescript
const handleResume = async () => {
  try {
    await sound.resumeRecorder();
    console.log('Recording resumed');
  } catch (error) {
    // Cannot resume (e.g., MediaRecorder was released by system)
    console.log('Cannot resume, starting new recording');
  }
};
```

### 7.3 Handling on iOS

```typescript
// On iOS, recording is STOPPED (not paused) on interruption
// Start a new recording if needed
const handleRestart = async () => {
  const newPath = await sound.startRecorder();
  console.log('New recording started:', newPath);
};
```

### 7.4 Best Practices

```typescript
// 1. Always call restorePendingRecordings() on app launch
useEffect(() => {
  sound.restorePendingRecordings().then(handleRestoredRecordings);
}, []);

// 2. Always handle isRecording: false callback
sound.addRecordBackListener((meta) => {
  if (!meta.isRecording) {
    // Update UI, save state
  }
});

// 3. Always wrap in try-catch
try {
  await sound.startRecorder(uri, audioSets);
} catch (error) {
  // Handle error (permission denied, etc.)
}

// 4. Always call stopRecorder() when user wants to finish
try {
  const filePath = await sound.stopRecorder();
  console.log('Recording saved:', filePath);
} catch (error) {
  console.error('Stop failed:', error);
}
```

---

## 8. FAQ

### Q: Why does recording pause when I open YouTube?

**A:** The library requests "audio focus" when recording. When YouTube (or any other audio app) also requests audio focus, the system notifies the library and recording is automatically paused. This is the correct behavior to avoid conflicts between apps.

### Q: Can I record while playing a video?

**A:** No. This causes audio focus conflicts and may lead to unexpected behavior. The user should stop the video before recording.

### Q: Why is the recording file corrupted after sudden power off?

**A:** M4A/MP4 files require a `moov` atom (metadata) at the end of the file to be playable. This is only written when `stopRecorder()` is called. If power is lost suddenly, this metadata is never written, making the file unplayable.

**Solution:** Use WAV recording mode. WAV files have their header at the beginning and raw PCM data afterwards, so even if power is lost, the audio data is preserved and can be restored using `restorePendingRecordings()`.

### Q: How do I recover recordings after a crash or power off?

**A:** Call `restorePendingRecordings()` when your app starts. This scans for incomplete WAV files, repairs their headers, converts them to M4A, and returns the file paths and durations.

```typescript
const restored = await sound.restorePendingRecordings();
// restored[0].uri = path to recovered M4A file
```

### Q: Does recording continue when the screen is off?

**A:** Yes. On Android, the library uses a Foreground Service with WakeLock. On iOS, the audio session with category `.playAndRecord` allows background recording.

### Q: What does the `isRecording: false` callback mean?

**A:** Recording has been paused (Android) or stopped (iOS). Possible causes:
- Incoming phone call
- Opening another audio/video app
- User called `pauseRecorder()` or `stopRecorder()`
- App was killed by user (swipe kill)

### Q: What is the maximum data loss with WAV recording?

**A:** Approximately 1-2 seconds. This is the unflushed buffer at the time of the crash. All previously written audio data is preserved on disk.

### Q: Can I restore M4A recordings after a crash?

**A:** No. If the recording was in M4A format and the app crashed before `stopRecorder()` was called, the file is missing the `moov` atom and cannot be recovered by this library. Only WAV recordings can be restored.

---

## 9. References

### Official Documentation

- [Android Process Lifecycle](https://developer.android.com/guide/components/activities/process-lifecycle)
- [Apple applicationWillTerminate](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:))
- [Apple Handling Audio Interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [Android AudioFocusRequest](https://developer.android.com/reference/android/media/AudioFocusRequest)
- [Apple Preserving Your App's UI Across Launches](https://developer.apple.com/documentation/uikit/preserving-your-app-s-ui-across-launches)

### OS Limitations

> "When an app is force-stopped, the entire process is killed instantly. Standard lifecycle methods such as onStop() and onDestroy() are not guaranteed to run."
> — [Android Developer Documentation](https://developer.android.com/guide/components/activities/process-lifecycle)
>
> "The system provides no notification when an app is terminated while in a suspended state."
> — [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:))

### Community Reports

- [Apple Discussions - Voice Memos Lost When Battery Dies](https://discussions.apple.com/thread/254003810)
- [Stack Overflow - MediaRecorder incomplete header](https://stackoverflow.com/questions/41704754)
- [Stack Overflow - Moov atom position in MediaRecorder](https://stackoverflow.com/questions/15338729)

---

## Changelog

- **v0.2.10:** Added audio focus handling for Android (video, Google Assistant, etc.)
- **v0.2.10:** Added `restorePendingRecordings()` and `restoreRecording()` methods
- **v0.2.10:** Added crash-resilient WAV recording mode
- **v0.2.9:** Added interruption handling for iOS
- **v0.2.8:** Added Foreground Service for Android
