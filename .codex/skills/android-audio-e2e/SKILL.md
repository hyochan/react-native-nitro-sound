---
name: android-audio-e2e
description: Build and run device-backed Android end-to-end checks for react-native-nitro-sound permissions, recording, playback, listeners, pause/resume, seek, speed, audio focus, lifecycle behavior, and rapid switching. Use for Kotlin or Android regressions and runtime claims beyond a Gradle compile.
---

# Android Audio E2E

Keep compilation, installation, and live audio verification as separate result
lanes.

## Safety And Scope

- Obtain explicit approval in the current run before starting live microphone
  capture. State that the example package `sound.example` will record a short
  test clip.
- Use non-sensitive audio. Do not upload, transcribe, or retain recordings
  beyond the verification need.
- Preserve existing ADB reverse rules, permissions, accounts, and device files.
- Test background recording, phone/audio-focus interruption, Bluetooth routing,
  or process death only when requested or required by the change.

## Preflight

1. Read `AGENTS.md`, `.github/workflows/ci-android.yml`, the changed
   Kotlin/spec/TS files, and the relevant example screen.
2. Record `git status --short --branch` and `adb devices -l`.
3. Confirm JDK 17, the Android SDK, and a single intended emulator or device.
4. Verify `RECORD_AUDIO` appears in the example manifest and identify the
   current permission state without changing it.
5. Run `yarn install --immutable` and `yarn nitrogen` when generated Android
   bindings are involved.

## Build Lane

Mirror the CI build:

```bash
yarn turbo run build:android --cache-dir=.turbo/android
```

If diagnosing Gradle directly, run the corresponding example task with
`--no-daemon --console=plain` and record the exact task and architecture.
Report `BUILD PASS` or `BUILD FAIL` independently.

## Device Runtime Lane

After microphone approval:

1. Install and launch `sound.example` on the selected device.
2. Grant microphone permission through Android's system UI; verify denial and
   retry behavior when permission handling is the target.
3. Start recording; require a resolved path, active state, and increasing
   millisecond callbacks.
4. Pause and resume; require time to pause and continue without duplicate
   recorder instances or promise settlement.
5. Stop; require terminal state, listener cleanup, and a non-empty app-owned
   recording.
6. Play the file; require increasing position, sensible duration, seek, volume,
   speed, and one playback-end transition as applicable.
7. Run Rapid Switch and Stress Test for MediaPlayer state or concurrency fixes.
8. Inspect filtered `adb logcat` for uncaught exceptions, rejected promises,
   media-state errors, and leaked recorder/player resources.

When lifecycle, audio focus, or background behavior is in scope, explicitly
exercise Home/Recent Apps, focus loss/gain, and relaunch. Do not claim process
death or background support unless the exact transition was observed.

## Evidence And Cleanup

Record the device serial, API level, ABI, build variant, permission state,
tested API/screen, callback progression, returned path metadata, and redacted
logs. Delete only recordings or temporary files created by the run. Report
`RUNTIME PASS`, `RUNTIME FAIL`, or `BLOCKED` separately and list untested rows.
