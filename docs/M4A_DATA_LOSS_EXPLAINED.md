# M4A Data Loss Explained & WAV Recovery Guide

## Table of Contents

1. [What Is M4A?](#1-what-is-m4a)
2. [M4A File Structure](#2-m4a-file-structure)
3. [Why Data Is Lost](#3-why-data-is-lost)
4. [WAV as a Crash-Resilient Alternative](#4-wav-as-a-crash-resilient-alternative)
5. [Recovery Architecture](#5-recovery-architecture)
6. [Scenario Analysis](#6-scenario-analysis)
7. [API Reference](#7-api-reference)
8. [References](#8-references)

---

## 1. What Is M4A?

**M4A** = MPEG-4 Audio = MP4 container with audio only (no video)

### Advantages
- ✅ Small file size (~1 MB per minute)
- ✅ Good quality (AAC codec)
- ✅ Widely supported
- ✅ Natively supported on both iOS and Android

### Disadvantages
- ❌ Metadata (`moov` atom) is written at the END of the file
- ❌ If `stop()` is never called, the file is unplayable
- ❌ Cannot recover data without the `moov` atom

---

## 2. M4A File Structure

### 2.1 Components

```
┌──────────────────────────────────────────────────┐
│  ftyp (File Type Box)                            │
│  - Size: 20-32 bytes                             │
│  - Content: "M4A ", "isom", "mp42"               │
│  - Written: At recording START                    │
├──────────────────────────────────────────────────┤
│  mdat (Media Data Box)                           │
│  - Size: Depends on recording duration           │
│  - Content: AAC encoded audio frames             │
│  - Written: CONTINUOUSLY during recording         │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │ AAC Frame 1 (20-40ms of audio)           │    │
│  │ AAC Frame 2                              │    │
│  │ AAC Frame 3                              │    │
│  │ ...                                      │    │
│  │ AAC Frame N                              │    │
│  └──────────────────────────────────────────┘    │
├──────────────────────────────────────────────────┤
│  moov (Movie Box) - THE CRITICAL PART!           │
│  - Size: A few KB                                │
│  - Written: ONLY when stop() is called!!!         │
│                                                  │
│  Contains:                                       │
│  ├─ mvhd: Duration, timescale                    │
│  ├─ trak: Track information                      │
│  │   └─ mdia: Media information                  │
│  │       └─ minf: Media details                  │
│  │           └─ stbl: Sample table               │
│  │               ├─ stts: Time-to-sample map     │
│  │               ├─ stsc: Sample-to-chunk map    │
│  │               ├─ stsz: Sample sizes           │
│  │               └─ stco: Chunk offsets          │
│  └─ udta: User data (optional)                   │
└──────────────────────────────────────────────────┘
```

### 2.2 Why Is `moov` at the End?

During recording, the encoder cannot know in advance:
- How long the recording will be
- How many AAC frames will be produced
- The exact size of each frame

This information can only be calculated after recording ends → `moov` is written last.

---

## 3. Why Data Is Lost

### 3.1 Normal Recording Flow

```
Step 1: Start recording
        → Write ftyp ✅
        → Begin writing mdat ✅

Step 2: Recording in progress...
        → Continuously write AAC frames to mdat ✅

Step 3: Call stopRecorder()
        → Finalize mdat ✅
        → CALCULATE AND WRITE moov ✅
        → File is complete ✅
```

### 3.2 Sudden Power Off / Force Stop

```
Step 1: Start recording
        → Write ftyp ✅
        → Begin writing mdat ✅

Step 2: Recording in progress...
        → Continuously write AAC frames ✅

Step 3: SUDDEN POWER OFF! ⚡
        → Process killed immediately
        → mdat not properly closed
        → moov NEVER WRITTEN ❌

Result:
┌──────┐ ┌──────────────────┐
│ ftyp │ │       mdat       │  ← MISSING moov!
└──────┘ └──────────────────┘

→ Player cannot open this file!
```

### 3.3 Why Players Cannot Open the File

Without `moov`, the player has no way to know:
- How long the file is
- Where each audio frame starts and ends
- What the sample rate, channels, and codec parameters are

**No `moov` = No "map" = Cannot decode!**

---

## 4. WAV as a Crash-Resilient Alternative

### 4.1 WAV File Structure

```
┌──────────────────────────────────┐
│  RIFF Header (44 bytes)          │  ← Written FIRST
│  - "RIFF"                        │
│  - File size (can be updated)    │
│  - "WAVE"                        │
│  - "fmt " + format info          │
│    (sample rate, channels, etc.) │
│  - "data" + data size            │
├──────────────────────────────────┤
│  PCM Audio Data                  │  ← Written continuously
│  - Sample 1                      │
│  - Sample 2                      │
│  - ...                           │
│  - Sample N                      │
└──────────────────────────────────┘
```

### 4.2 WAV After Sudden Power Off

```
┌──────────────────────────────────┐
│  RIFF Header (44 bytes)          │  ← Already written, size may be wrong
├──────────────────────────────────┤
│  PCM Audio Data                  │  ← DATA IS STILL INTACT!
│  - Sample 1 ... Sample N        │
└──────────────────────────────────┘

→ Header size fields may be wrong
→ But the audio data is valid raw PCM
→ Header can be REPAIRED by recalculating file size
→ Only ~1-2 seconds of audio lost (unflushed buffer)
```

### 4.3 Comparison Table

| Aspect | M4A/MP4 | WAV |
|--------|---------|-----|
| File size | ~1 MB/min | ~10 MB/min |
| Metadata position | End of file | Beginning of file |
| Sudden power off | ❌ 100% data loss | ✅ ~1-2 second loss |
| Force stop | ❌ 100% data loss | ✅ ~1-2 second loss |
| Battery death | ❌ 100% data loss | ✅ ~1-2 second loss |
| App crash | ❌ 100% data loss | ✅ ~1-2 second loss |
| Quality | Lossy (AAC) | Lossless (PCM) |
| Can be recovered | ❌ No | ✅ Yes |
| Can be converted to M4A | N/A | ✅ Yes (after recovery) |

---

## 5. Recovery Architecture

### 5.1 Recording Flow

```
                     startRecorder()
                          │
                          ▼
              ┌─────────────────────┐
              │   Record to WAV     │
              │   (crash-resilient) │
              └─────────┬───────────┘
                        │
            ┌───────────┴───────────┐
            │                       │
      Normal Stop              Crash/Kill
            │                       │
            ▼                       ▼
    ┌───────────────┐     ┌──────────────────┐
    │ stopRecorder()│     │ WAV file on disk  │
    │ → Update WAV  │     │ (header may be   │
    │   header      │     │  incomplete)     │
    │ → Convert to  │     └────────┬─────────┘
    │   M4A         │              │
    │ → Return M4A  │     Next app launch
    │   path        │              │
    └───────────────┘              ▼
                          ┌──────────────────────┐
                          │ restorePending        │
                          │ Recordings()          │
                          │                       │
                          │ 1. Scan for .wav files│
                          │ 2. Repair headers     │
                          │ 3. Convert to M4A     │
                          │ 4. Delete WAV files   │
                          │ 5. Return M4A paths   │
                          └──────────────────────┘
```

### 5.2 Header Repair Process

```kotlin
// WavRecorder.repairWavFile()
fun repairWavFile(filePath: String): Boolean {
    val file = File(filePath)
    val dataSize = file.length() - 44  // 44 = WAV header size
    val fileSize = dataSize + 44 - 8   // RIFF chunk size

    RandomAccessFile(file, "rw").use { raf ->
        // Fix RIFF chunk size at byte offset 4
        raf.seek(4)
        raf.write(intToByteArray(fileSize.toInt()))

        // Fix data chunk size at byte offset 40
        raf.seek(40)
        raf.write(intToByteArray(dataSize.toInt()))
    }
    // Now the WAV file is fully playable!
}
```

---

## 6. Scenario Analysis

### 6.1 Scenarios That Are Handled

| Scenario | How It's Handled | Result |
|----------|-----------------|--------|
| User presses Stop | `stop()` called normally | ✅ Complete file |
| User swipe-kills app | `onTaskRemoved()` calls `stop()` | ✅ Complete file |
| Incoming call (iOS) | `interruptionNotification` → `stop()` | ✅ Complete file |
| Incoming call (Android) | Audio focus loss → `pause()` | ✅ Can resume or stop |
| Open video/music app | Audio focus loss → `pause()` | ✅ Can resume or stop |

### 6.2 Scenarios Recoverable with WAV

| Scenario | Without WAV | With WAV + Restore |
|----------|-------------|-------------------|
| Sudden power off | ❌ 100% loss | ✅ ~1-2s loss, recoverable |
| Battery dies suddenly | ❌ 100% loss | ✅ ~1-2s loss, recoverable |
| Force stop from Settings | ❌ 100% loss | ✅ ~1-2s loss, recoverable |
| App crash (exception) | ❌ 100% loss | ✅ ~1-2s loss, recoverable |
| System kills app (OOM) | ❌ Possible loss | ✅ ~1-2s loss, recoverable |

### 6.3 OS Limitations

Both Android and iOS have documented limitations:

**Android:**
> "When an app is force-stopped, the entire process is killed instantly. Standard lifecycle methods such as onStop() and onDestroy() are not guaranteed to run."

**iOS:**
> "The system provides no notification when an app is terminated while in a suspended state."

Even native recording apps (Apple Voice Memos, Samsung Voice Recorder) are affected:
> "Voice memos are completely lost when iPhone battery runs out."
> — [Apple Discussions](https://discussions.apple.com/thread/254003810)

---

## 7. API Reference

### restorePendingRecordings(directory?)

Scans a directory for incomplete WAV files, repairs them, converts to M4A, and returns results.

```typescript
restorePendingRecordings(directory?: string): Promise<RestoredRecording[]>
```

**Parameters:**
- `directory` (optional): Path to scan. Defaults to the app's recording directory.

**Returns:** Array of `RestoredRecording` objects.

**Example:**

```typescript
// On app launch
const restored = await sound.restorePendingRecordings();

for (const recording of restored) {
  console.log('Recovered:', recording.uri);
  console.log('Duration:', recording.duration, 'ms');
  console.log('Original WAV:', recording.originalPath);
  
  // Save to your database, upload, etc.
}
```

### restoreRecording(wavFilePath)

Restores a single WAV recording file.

```typescript
restoreRecording(wavFilePath: string): Promise<RestoredRecording>
```

**Parameters:**
- `wavFilePath`: Path to the WAV file to restore.

**Returns:** A `RestoredRecording` object.

**Example:**

```typescript
const recording = await sound.restoreRecording('/path/to/recording.wav');
console.log('Restored M4A:', recording.uri);
```

### RestoredRecording

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

---

## 8. References

### Official Documentation

- [Android Process Lifecycle](https://developer.android.com/guide/components/activities/process-lifecycle)
- [Apple applicationWillTerminate](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:))
- [MP4 File Structure (QuickTime)](https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html)

### Community Reports

- [Apple Discussions - Voice Memos Lost When Battery Dies](https://discussions.apple.com/thread/254003810)
- [Stack Overflow - MediaRecorder incomplete header](https://stackoverflow.com/questions/41704754)
- [Stack Overflow - Moov atom position in MediaRecorder](https://stackoverflow.com/questions/15338729)

### Recovery Tools (for manual M4A repair)

- [Restore.Media - M4A Repair](https://restore.media/blog/repair-m4a-file)
- [FFmpeg - faststart option](https://ffmpeg.org/ffmpeg-formats.html#mov_002c-mp4_002c-ismv)
