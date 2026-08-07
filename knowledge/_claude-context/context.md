# react-native-nitro-sound — AI Context

> Maintained from repository source. Refresh with `/compile-knowledge` after
> public API, native behavior, compatibility, dependency, or workflow changes.

## Repository Purpose

`react-native-nitro-sound` is a typed React Native audio recording and playback
library built on `react-native-nitro-modules`. It provides a Nitro HybridObject,
React hooks, legacy singleton compatibility, and a Web implementation, with an
example app for iOS, Android, and browsers.

## Architecture

- Contract: `src/specs/Sound.nitro.ts`
- TypeScript factory and legacy singleton: `src/index.tsx`
- Web implementation: `src/index.web.tsx`
- Hooks: `src/useSound*.ts` and `src/useSoundRecorder*.ts`
- iOS: `ios/Sound.swift` using AVFoundation
- Android: `android/src/main/java/com/margelo/nitro/audiorecorderplayer/Sound.kt`
- Generated bindings: `nitrogen/generated/**`; regenerate, never hand-edit
- Example: `example/` with direct, hook, state-hook, compatibility, and rapid
  switching screens

The `Sound` autolinking entry is declared in `nitro.json`. A spec change must be
regenerated before native builds or publication.

## Current Package Baseline

- Library version: `0.2.18`
- Package manager: Yarn `4.18.0`
- Node baseline: `.nvmrc` `22.21.0`; package engines `>=22.21.0`
- React Native Nitro Modules: development `0.36.5`, peer `>=0.36.5`
- Nitrogen: `0.36.5`
- Example React Native: `0.86.2`; Expo `57.0.11`
- iOS minimum: `15.1`; Android minimum: `24`
- Xcode minimum: `26.0`; iOS CI: macOS `15` with Xcode `26.3`
- Native toolchain: CocoaPods `1.17.0`, compile/target SDK `36`, Gradle
  `9.3.1`, Kotlin `2.1.20`

Always re-read `package.json`, Podspec, Gradle files, and CI before relying on
these values; this file can lag during an active dependency change.

## Public Entry Points

- Default `Sound` singleton and named `Sound` singleton
- `createSound()` for independent HybridObject instances
- `useSound()` and `useSoundWithStates()`
- `useSoundRecorder()` / `useAudioRecorder()`
- `useSoundRecorderWithStates()` / `useAudioRecorderWithStates()`
- All enums, types, listener payloads, and `Sound` interface from
  `src/specs/Sound.nitro.ts`

## Sound Contract

Recording:

- `startRecorder(uri?, audioSets?, meteringEnabled?): Promise<string>`
- `pauseRecorder(): Promise<string>`
- `resumeRecorder(): Promise<string>`
- `stopRecorder(): Promise<string>`

Playback:

- `startPlayer(uri?, httpHeaders?): Promise<string>`
- `stopPlayer()`, `pausePlayer()`, and `resumePlayer()`
- `seekToPlayer(time)`, `setVolume(volume)`, and
  `setPlaybackSpeed(playbackSpeed)`

Events and utilities:

- `setSubscriptionDuration(sec)`
- record, playback, and playback-end listener add/remove pairs
- `mmss(secs)` and `mmssss(milisecs)`

Record and playback positions are milliseconds. Preserve listener cleanup,
single promise settlement, and exactly one terminal playback transition.

## Platform Notes

### iOS

- Uses `AVAudioSession`, `AVAudioRecorder`, and `AVAudioPlayer`.
- Microphone permission and session activation are asynchronous.
- Recording and playback behavior involving interruption, routing, background
  state, or Release-only Swift/C++ bridging needs device or configuration-
  specific evidence.
- The CI build runs on macOS 15 with Xcode 26.3, then runs `yarn prepare`,
  `fix-nitrogen-swift.sh`, Pods, and the `SoundExample` simulator workspace
  build.

### Android

- Uses `MediaRecorder` and `MediaPlayer` with promise-based operations and
  listener timers.
- Verify `RECORD_AUDIO`, MediaPlayer state safety, audio focus/lifecycle, and
  cleanup for runtime changes.
- CI generates Nitrogen bindings and builds the arm64-v8a example through the
  Turborepo Android task with JDK 17.

### Web

- Uses browser `MediaRecorder`, `Audio`, Blob/object URLs, and timers.
- Verify MIME fallback support, permission errors, timer cleanup, duration
  units, object URL lifecycle, and playback-end behavior in a real browser.

## Verification Matrix

- Baseline: `yarn typecheck`, `yarn lint`, `yarn test`, `git diff --check`
- Build/codegen: `yarn prepare`; inspect all generated changes
- Web: `yarn build:web`
- Android/iOS: mirror `.github/workflows/ci-android.yml` and `ci-ios.yml`
- Runtime: use `$simulator-audio-e2e` for the canonical Maestro regression
  flow; `$android-audio-e2e` and `$ios-audio-e2e` cover deeper platform cases

## Maintenance Workflows

- Router: `$nitro-sound-workflows`
- PR feedback and monitoring: `$review-pr` (`/review-pr` is the Claude adapter)
- Audit: `/audit-code`
- Full checks: `/verify-all`
- Device/browser regression: `/e2e-tests`
- Simulator-only audio regression: `$simulator-audio-e2e`
- Release: `/release`
- Issue resolution: `/resolve-issue`
- Dependency updates: `/upgrade-deps`
- Git publication: `/commit`
- Safe synchronization: `$rebase-main`
- Final review: `$review-self`

Keep workflow-only edits local unless the user explicitly requests GitHub
publication.
