---
name: simulator-audio-e2e
description: Build and run repeatable react-native-nitro-sound recorder/player regression tests on an iOS Simulator or Android emulator, with explicit virtual-device selection, microphone permission, Maestro evidence, native log inspection, and cleanup. Use after dependency, Nitro, TypeScript, Swift, Kotlin, generated-binding, or audio state-machine changes when a physical device is not required.
---

# Simulator Audio E2E

Verify real native recording and playback on virtual devices without touching a
connected physical phone. Treat builds, UI automation, callback state, and log
inspection as separate evidence.

## Safety Boundary

- Require explicit permission in the current request before recording. State
  that `sound.example` records a short non-sensitive clip through the host or
  emulator microphone. A request to run audio E2E is sufficient permission.
- Select a concrete iOS Simulator UDID or Android serial beginning with
  `emulator-`. Never allow an implicit destination when physical devices are
  connected.
- Do not upload, transcribe, or retain the recording. Keep only screenshots,
  JUnit output, and redacted logs needed to diagnose the run.
- Do not claim Bluetooth, interruptions, backgrounding, audio focus, route
  changes, or audible fidelity from this lane; those require targeted tests and
  can require a physical device.

## Preflight

1. Read `AGENTS.md`, `.claude/commands/e2e-tests.md`, the changed source, and
   `references/flow-contract.md`.
2. Preserve `git status --short --branch`; never clean unrelated work.
3. Run `scripts/preflight.sh` and select one available virtual destination.
4. Run `yarn install --immutable`, `yarn prepare`, `yarn typecheck`,
   `yarn lint`, and `yarn test --runInBand`.
5. Confirm `sound.example` declares microphone permission and no Metro process
   conflict exists on port 8081.

## Build And Install

For iOS, boot the selected Simulator and build the Debug app for that exact
UDID. Install the produced `.app` with `xcrun simctl install`. For Android,
start the selected AVD, wait for boot completion, and build/install Debug with
`ANDROID_SERIAL` set to the selected emulator serial.

Start Metro from the repository root with `yarn start --reset-cache`. Keep its
session and save errors separately from native device logs. Grant microphone
permission to `sound.example` on the selected virtual device before the flow.

## Run The Runtime Contract

Run the repository flow through the guarded helper:

```bash
.codex/skills/simulator-audio-e2e/scripts/run-maestro.sh ios <simulator-udid>
.codex/skills/simulator-audio-e2e/scripts/run-maestro.sh android <emulator-serial>
```

The flow must prove both direct and hook APIs can:

1. Start recording and emit increasing record time.
2. Pause and resume the recorder without a crash or duplicate instance.
3. Stop and expose a playable path.
4. Start, pause, resume, and stop playback with matching UI state.
5. Complete with no visible error alert.

Do not weaken selectors or remove state assertions to make a failed flow pass.
Fix the product or explain a platform limitation.

## Inspect Native Evidence

After Maestro, inspect simulator logs for the current app process only:

- iOS: `xcrun simctl spawn <udid> log show` with a short time bound and a
  `sound.example` predicate.
- Android: `adb -s <serial> logcat --pid=$(adb -s <serial> shell pidof
  sound.example)` captured around the run.

Fail the runtime lane for uncaught exceptions, native crashes, rejected
promises, MediaRecorder/AVAudio errors, or leaked-resource warnings attributable
to the tested flow. Ignore unrelated host and OS noise with an explanation.

## Report And Cleanup

Report `BUILD PASS/FAIL` and `RUNTIME PASS/FAIL/BLOCKED` per platform. Include
the exact UDID/serial, OS/API level, RN and Nitro versions, flow path, callback
states observed, JUnit result, and relevant redacted log findings. List every
untested device-only row.

Terminate only Metro/emulators started by this run. Leave user-owned devices
and processes intact. Remove the created recording or uninstall the cleared
test app when practical; artifacts under `e2e/artifacts/` are disposable and
ignored by Git.
