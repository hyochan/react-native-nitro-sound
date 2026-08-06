---
name: ios-audio-e2e
description: Build and run device-backed iOS end-to-end checks for react-native-nitro-sound recording, playback, listeners, pause/resume, seek, speed, interruption, audio-session behavior, and rapid switching. Use for iOS audio regressions, Swift changes, or claims that require more than an Xcode compile.
---

# iOS Audio E2E

Separate build evidence from live microphone and speaker evidence. Never report
an iOS runtime pass from a simulator compile alone.

## Safety And Scope

- Obtain explicit approval in the current run before starting live microphone
  capture. State that the example app `sound.example` will record a short clip.
- Use a test device and non-sensitive audio. Do not retain, upload, transcribe,
  or inspect recorded content beyond what is needed to prove the flow.
- Preserve the user's signing, simulator, device, and audio-session settings.
- Treat calls, Bluetooth routing, backgrounding, and other-app interruptions as
  separate opt-in rows; they alter device state and are not implied by a basic
  E2E request.

## Preflight

1. Read `AGENTS.md`, `.github/workflows/ci-ios.yml`, the changed Swift/spec/TS
   files, and the relevant example screen.
2. Record `git status --short --branch`; do not discard existing changes.
3. Run `xcodebuild -version` and `xcrun simctl list devices available` or
   `xcrun devicectl list devices` for a physical device.
4. Confirm `example/ios/SoundExample/Info.plist` contains a microphone usage
   description and identify the selected destination.
5. Run `yarn install --immutable`, `yarn prepare`, and
   `./scripts/fix-nitrogen-swift.sh` when generated Swift is involved.

## Build Lane

Mirror `.github/workflows/ci-ios.yml`:

```bash
cd example
bundle install
bundle exec pod install --project-directory=ios
cd ..
xcodebuild \
  -workspace example/ios/SoundExample.xcworkspace \
  -scheme SoundExample \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  SKIP_BUNDLING=YES \
  build
```

Report this as `BUILD PASS` or `BUILD FAIL`, never as runtime E2E.

## Device Runtime Lane

After microphone approval, run the smallest matrix covering the change:

1. Install and launch the example on the selected iPhone or a simulator with a
   known audio input.
2. Grant microphone permission through the system prompt.
3. Start recording; require a resolved URI, `isRecording`, and increasing
   millisecond callbacks.
4. Pause and resume; require callback time to stop and then advance without a
   second recorder instance.
5. Stop; require a terminal state, listener cleanup, and a playable file.
6. Play the recorded clip; require increasing playback position and duration.
7. Exercise seek, volume, and playback speed when affected.
8. Require exactly one playback-end transition and successful stop/cleanup.
9. Run the Rapid Switch screen for concurrency or promise-settlement changes.

For interruption, route change, or background work, capture the before/after
audio-session state and verify recovery on a physical device. A manual gesture
without matching app state and logs is insufficient.

## Evidence And Cleanup

Capture the device identifier, iOS/Xcode versions, build configuration, tested
screen/API, permission state, callback progression, returned path, and relevant
redacted logs. Remove only recordings and temporary artifacts created by the
current run. Report `RUNTIME PASS`, `RUNTIME FAIL`, or `BLOCKED` separately from
the build result and list every untested row.
