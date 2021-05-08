## Changelogs
- **[3.0.0]**
  - 3.0.0-beta.2
    - Add `resumeRecorder` and `pauseRecorder` features.
      - **Caveat**: Android now requires min sdk of `24`.
    - Renamed listener callback variables from `snake_case` to `camelCase`.
      * Below are return types.
        ```ts
        export type RecordBackType = {
          isRecording?: boolean;
          currentPosition: number;
          currentMetering?: number;
        };

        export type PlayBackType = {
          isMuted?: boolean;
          currentPosition: number;
          duration: number;
        };
        ```
  - 3.0.0-beta.1
    - [iOS]
      * Codebase re-written in `Swift`.
      * Migrate `AVAudioPlayer` to `AVPlayer`.

- **[2.7.0]**
  - Migrate `android` module to `kotlin`.
- **[2.6.2]**
  - Support for Linear PCM format settings [#269](https://github.com/dooboolab/react-native-audio-recorder-player/pull/269)
- **[2.6.1]**
  - Remove extra stopping condition in playback listener [#251](https://github.com/dooboolab/react-native-audio-recorder-player/pull/251)
- **[2.6.0]**
  - Add support on adding `httpHeaders` for the audio that is not permitted to play without network authorization.
  - Bugfix on seeking player [#242](https://github.com/dooboolab/react-native-audio-recorder-player/pull/242)
- **[2.5.4]**
  - Fixes on wrong arg type issue when recording [#230](https://github.com/dooboolab/react-native-audio-recorder-player/issues/230)
- **[2.5.3]**
  - Add try catch block on `mediaRecorder.stop()` [#220](https://github.com/dooboolab/react-native-audio-recorder-player/pull/220)
- **[2.5.2]**
  - Add android record parameters [#210](dooboolab/react-native-audio-recorder-player/issues/210)
  - Play music in bluetooth earpiece while recording [#192](dooboolab/react-native-audio-recorder-player/issues/192)
  - Adding optional volume metering [#191](dooboolab/react-native-audio-recorder-player/issues/191)
  - Upgrade packages
- **[2.5.1]**
  - Resolve [#157](https://github.com/dooboolab/react-native-audio-recorder-player/issues/157), android path problem once again.
- **[2.5.0]**
  - Handle stop once player is paused [#169](https://github.com/dooboolab/react-native-audio-recorder-player/pull/169)
  - Add custom path for ios [#168](https://github.com/dooboolab/react-native-audio-recorder-player/pull/168)
- **[2.4.+]**
  - Migrated to `ts` project and also support `flow` types.
- **[2.3.+]**
  - Add ability to customize recorder parameters [#114](https://github.com/dooboolab/react-native-audio-recorder-player/pull/114)
- **[2.2.+]**
  - Migrated to androidx [#82](https://github.com/dooboolab/react-native-audio-recorder-player/pull/82)
  - Makes path param in startRecord to behave as a path on iOS [#94](https://github.com/dooboolab/react-native-audio-recorder-player/pull/94)
  - Update podspec for RN 0.60 [#93](https://github.com/dooboolab/react-native-audio-recorder-player/pull/93)
  - fixed RN60 CocoaPods installation [#106](https://github.com/dooboolab/react-native-audio-recorder-player/pull/106)
  - Update RNAudioRecorderPlayerModule.java [#107](https://github.com/dooboolab/react-native-audio-recorder-player/pull/107)
- **[2.1.4]**
  - remove extra ext from `android` gradle versions references as rootProjet [#47](remove extra ext from android gradle versions references as rootProje).
- **[2.1.2]**
  - Update build gradle.
- **[2.1.1]**
  - Support gradle 4.0+ and drop below.
- **[2.0.9]**
  - Avoid iml file in npm that may result in build failure.
- **[2.0.7]**
  - Try prevent quiting after permission request in android.
- **[2.0.6]**
  - Invalidate timer when audio duration is 0 in ios.
  - volume control.
- **[2.0.5]**
  - Removed recordInterval from type.
- **[2.0.4]**
  - resumePlayer type was missing.
- **[2.1.0]**
  - Added beautiful logo made by [mansya](mansya)
- **[2.0.2]**
  - Safer build setting for android.
  - Updated readme.
- **[2.0.0]**
  - Propler callback handler for recorder.
  - Improved codes and types.
  - Methods renaming.
  - Upgraded example projects.
- **[1.2.2]**
  - Set android build version to that of `rootProject`'s to prevent from build failing cause of mismatched version.
