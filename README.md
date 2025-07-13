# react-native-audio-recorder-player

<img src="Logotype Primary.png" width="70%" />

[![yarn Version](http://img.shields.io/npm/v/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![Downloads](http://img.shields.io/npm/dm/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![CI](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/ci.yml/badge.svg)](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/ci.yml)
[![publish-package](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/publish-package.yml/badge.svg)](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/publish-package.yml)
![License](http://img.shields.io/npm/l/react-native-audio-recorder-player.svg?style=flat-square)
[![supports iOS](https://img.shields.io/badge/iOS-4630EB.svg?style=flat-square&logo=APPLE&labelColor=999999&logoColor=fff)](https://itunes.apple.com/app/apple-store/id982107779)
[![supports Android](https://img.shields.io/badge/Android-4630EB.svg?style=flat-square&logo=ANDROID&labelColor=A4C639&logoColor=fff)](https://play.google.com/store/apps/details?id=host.exp.exponent&referrer=www)
[![code style: prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square)](https://github.com/prettier/prettier)
[![LICENSE](http://img.shields.io/npm/l/@react-native-seoul/masonry-list.svg?style=flat-square)](https://npmjs.org/package/@react-native-seoul/masonry-list)

**🎉 Version 4.1.0 Released with NitroModule Support!**

> ⚠️ **Important**: Version 4.0.0 had issues with Nitro integration. Please install version 4.1.0 or later.

This is a high-performance React Native module for audio recording and playback, now powered by [NitroModules](https://github.com/mrousavy/nitro) for direct native module access without bridge overhead. The library provides simple recorder and player functionalities for both Android and iOS platforms with full TypeScript support and type safety.

## Preview

<img src="https://user-images.githubusercontent.com/27461460/117547014-3fe52000-b068-11eb-9f34-2bfc1e5092fd.gif" width=300/>

## Documentation & Resources

- 📚 [Version 4.0.0 Migration Guide](#whats-new-in-400-)
- 📝 [Version 3 Release Note](https://medium.com/dooboolab/react-native-audio-player-and-recorder-v3-7697e25cd07)
- 📰 [Original Blog Post](https://medium.com/@dooboolab/react-native-audio-recorder-and-player-4aa5f26a666)
- 🔧 [NitroModules Documentation](https://github.com/mrousavy/nitro)

## What's New in 4.0.0 🚀

### NitroModule Migration

Version 4.0.0 introduces a complete rewrite using [NitroModules](https://github.com/mrousavy/nitro), offering:

- **Zero Bridge Overhead**: Direct native module access for maximum performance
- **Full Type Safety**: TypeScript definitions generated from native specs
- **Synchronous Methods**: Where appropriate, for better developer experience
- **Event Listeners**: Native callbacks with type-safe event payloads
- **Cross-Platform Code Generation**: Automatic code generation for iOS (Swift) and Android (Kotlin)

### Requirements

- React Native >= 0.73.0
- iOS >= 13.0
- Android minSdk >= 24
- Expo SDK >= 50 (for Expo users)

## Breaking Changes from 3.x

### API Changes

1. **Import Change**: The module is now imported differently:

   ```ts
   // Before (3.x)
   import AudioRecorderPlayer from 'react-native-audio-recorder-player';
   const audioRecorderPlayer = new AudioRecorderPlayer();

   // After (4.0.0)
   import AudioRecorderPlayer from 'react-native-audio-recorder-player';
   const audioRecorderPlayer = new AudioRecorderPlayer();
   ```

2. **Event Listeners**: Updated event listener API:

   ```ts
   // Recording progress
   audioRecorderPlayer.addRecordBackListener((e) => {
     console.log('Recording:', e.currentPosition, e.currentMetering);
   });

   // Playback progress
   audioRecorderPlayer.addPlayBackListener((e) => {
     console.log('Playback:', e.currentPosition, e.duration);
   });
   ```

3. **Promise Return Types**: All methods now have proper TypeScript types

### Previous Breaking Changes (3.x)

- From version `3.0.+`, a critical migration has been done. Also note that it supports `iOS` platform version `10.0` or newer.
  1. Codebase has been re-written to [kotlin for Android](https://kotlinlang.org) and [swift for iOS](https://swift.org). Please follow the [post installation](https://github.com/hyochan/react-native-audio-recorder-player#post-installation) for this changes.

     [iOS]
     - [AVAudioPlayer](https://developer.apple.com/documentation/avfaudio/avaudioplayer) has been migrated to [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer) which supports stream and more possibilities [#231](https://github.com/hyochan/react-native-audio-recorder-player/issues/231), [#245](https://github.com/hyochan/react-native-audio-recorder-player/issues/245), [#275](https://github.com/hyochan/react-native-audio-recorder-player/issues/275).

  2. `pauseRecorder` and `resumeRecorder` features are added.
     - **Caveat**
       Android now requires `minSdk` of `24`.
  3. Renamed callback variables.

     ```ts
     export type RecordBackType = {
       isRecording?: boolean;
       currentPosition: number;
       currentMetering?: number;
       recordSecs: number;
     };

     export type PlayBackType = {
       isMuted?: boolean;
       currentPosition: number;
       duration: number;
     };
     ```

  4. `subscriptionDuration` offset not defaults to `0.5` which is `500ms`.
     - Resolve [#273](https://github.com/hyochan/react-native-audio-recorder-player/issues/273)

## Migration Guide

### From 1.x to 2.x/3.x

| 1.x.x                  | 2.x.x & 3.x.x             |
| ---------------------- | ------------------------- |
| `startRecord`          | `startRecorder`           |
|                        | `pauseRecorder` (3.x.x)   |
|                        | `resumeRecorder` (3.x.x)  |
| `stopRecord`           | `stopRecorder`            |
| `startPlay`            | `startPlayer`             |
| `stopPlay`             | `stopPlayer`              |
| `pausePlay`            | `pausePlayer`             |
| `resume`               | `resumePlayer`            |
| `seekTo`               | `seekToPlayer`            |
|                        | `setSubscriptionDuration` |
| `addPlayBackListener`  | `addPlayBackListener`     |
| `setRecordInterval`    | `addRecordBackListener`   |
| `removeRecordInterval` | ``                        |
|                        | `setVolume`               |

## Getting started

> ⚠️ **Important**: Install version 4.1.0 or later to avoid Nitro integration issues from version 4.0.0.

1. **Install packages**:

   ```sh
   yarn add react-native-audio-recorder-player react-native-nitro-modules
   ```

   Or using npm:

   ```sh
   npm install react-native-audio-recorder-player react-native-nitro-modules
   ```

## Post Installation

After installing the packages, follow these steps:

1. **Generate NitroModule bindings**:
   ```sh
   # Using yarn
   yarn nitro-codegen
   
   # Or using npm
   npx nitro-codegen
   ```
   This generates the necessary native code bindings for both iOS and Android platforms.

2. **iOS Setup**:
   ```sh
   cd ios && pod install
   ```

3. **Android Setup**:
   No additional steps required. The module uses autolinking.

## Platform-specific Configuration

### iOS Configuration

1. **Microphone Permission**: Add to your `Info.plist`:

   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>Give $(PRODUCT_NAME) permission to use your microphone. Your record wont be shared without your permission.</string>
   ```

2. **Minimum iOS Version**: Ensure your minimum deployment target is iOS 13.0 or higher in your `Podfile`:
   ```ruby
   platform :ios, '13.0'
   ```

### Android Configuration

On _Android_ you need to add a permission to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

Also, android above `Marshmallow` needs runtime permission to record audio. Below is sample usage:

```ts
if (Platform.OS === 'android') {
  try {
    const grants = await PermissionsAndroid.requestMultiple([
      PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
    ]);

    if (
      grants['android.permission.WRITE_EXTERNAL_STORAGE'] ===
        PermissionsAndroid.RESULTS.GRANTED &&
      grants['android.permission.READ_EXTERNAL_STORAGE'] ===
        PermissionsAndroid.RESULTS.GRANTED &&
      grants['android.permission.RECORD_AUDIO'] ===
        PermissionsAndroid.RESULTS.GRANTED
    ) {
      console.log('Permissions granted');
    } else {
      console.log('All required permissions not granted');
      return;
    }
  } catch (err) {
    console.warn(err);
    return;
  }
}
```

## Methods

| Method                   |                      Param                       |      Return       | Description                                           |
| :----------------------- | :----------------------------------------------: | :---------------: | :---------------------------------------------------- |
| mmss                     |                 `number` seconds                 |     `string`      | Convert seconds to `minute:second` string             |
| mmssss                   |                 `number` seconds                 |     `string`      | Convert seconds to `minute:second:millisecond` string |
| setSubscriptionDuration  |                `number` duration                 |      `void`       | Set callback interval in ms (default 500ms)           |
| startRecorder            |       `string?` uri, `AudioSet?` audioSet,       | `Promise<string>` | Start recording with optional path and audio settings |
|                          |            `boolean?` meteringEnabled            |                   |                                                       |
| pauseRecorder            |                                                  | `Promise<string>` | Pause recording                                       |
| resumeRecorder           |                                                  | `Promise<string>` | Resume recording                                      |
| stopRecorder             |                                                  | `Promise<string>` | Stop recording and return file path                   |
| startPlayer              | `string?` uri, `Record<string, string>?` headers | `Promise<string>` | Start playback with optional URI and HTTP headers     |
| stopPlayer               |                                                  | `Promise<string>` | Stop playback                                         |
| pausePlayer              |                                                  | `Promise<string>` | Pause playback                                        |
| resumePlayer             |                                                  | `Promise<string>` | Resume playback                                       |
| seekToPlayer             |              `number` milliseconds               | `Promise<string>` | Seek to position in milliseconds                      |
| setVolume                |                  `number` value                  | `Promise<string>` | Set volume (0.0 - 1.0)                                |
| setPlaybackSpeed         |                  `number` speed                  | `Promise<string>` | Set playback speed (0.5 - 2.0)                        |
| addRecordBackListener    |               `Function` callback                |      `void`       | Add recording progress listener                       |
| removeRecordBackListener |                                                  |      `void`       | Remove recording progress listener                    |
| addPlayBackListener      |               `Function` callback                |      `void`       | Add playback progress listener                        |
| removePlayBackListener   |                                                  |      `void`       | Remove playback progress listener                     |

## Usage

### Basic Usage

```typescript
import AudioRecorderPlayer, {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
  AVEncodingOption,
  RecordBackType,
  PlayBackType,
} from 'react-native-audio-recorder-player';

const audioRecorderPlayer = new AudioRecorderPlayer();

// Recording
const onStartRecord = async () => {
  // Set up recording progress listener
  audioRecorderPlayer.addRecordBackListener((e: RecordBackType) => {
    console.log('Recording progress:', e.currentPosition, e.currentMetering);
    setRecordSecs(e.currentPosition);
    setRecordTime(audioRecorderPlayer.mmssss(Math.floor(e.currentPosition)));
  });

  const result = await audioRecorderPlayer.startRecorder();
  console.log('Recording started:', result);
};

const onStopRecord = async () => {
  const result = await audioRecorderPlayer.stopRecorder();
  audioRecorderPlayer.removeRecordBackListener();
  console.log('Recording stopped:', result);
};

// Playback
const onStartPlay = async () => {
  // Set up playback progress listener
  audioRecorderPlayer.addPlayBackListener((e: PlayBackType) => {
    console.log('Playback progress:', e.currentPosition, e.duration);
    setCurrentPosition(e.currentPosition);
    setTotalDuration(e.duration);
    setPlayTime(audioRecorderPlayer.mmssss(Math.floor(e.currentPosition)));
    setDuration(audioRecorderPlayer.mmssss(Math.floor(e.duration)));
  });

  const result = await audioRecorderPlayer.startPlayer();
  console.log('Playback started:', result);
};

const onPausePlay = async () => {
  await audioRecorderPlayer.pausePlayer();
};

const onStopPlay = async () => {
  audioRecorderPlayer.stopPlayer();
  audioRecorderPlayer.removePlayBackListener();
};

// Seeking
const seekTo = async (milliseconds: number) => {
  await audioRecorderPlayer.seekToPlayer(milliseconds);
};

// Volume control
const setVolume = async (volume: number) => {
  await audioRecorderPlayer.setVolume(volume); // 0.0 - 1.0
};

// Speed control
const setSpeed = async (speed: number) => {
  await audioRecorderPlayer.setPlaybackSpeed(speed); // 0.5 - 2.0
};
```

### Audio Configuration

```typescript
const audioSet: AudioSet = {
  // iOS Settings
  AVSampleRateKeyIOS: 44100,
  AVFormatIDKeyIOS: AVEncodingOption.aac,
  AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
  AVNumberOfChannelsKeyIOS: 2,

  // Android Settings
  AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
  AudioSourceAndroid: AudioSourceAndroidType.MIC,
};

const meteringEnabled = true; // Enable audio metering

const uri = await audioRecorderPlayer.startRecorder(
  undefined, // Use default path
  audioSet,
  meteringEnabled
);
```

## Default Path

- Default path for android uri is `{cacheDir}/sound.mp4`.
- Default path for ios uri is `{cacheDir}/sound.m4a`.

## Example App

### Running the Example

1. Navigate to the example directory:

   ```sh
   cd example
   ```

2. Install dependencies:

   ```sh
   yarn install
   ```

3. Generate NitroModule bindings:

   ```sh
   yarn nitro-codegen
   ```

4. Start the development server:

   ```sh
   yarn start
   ```

5. Run on your platform:

   ```sh
   # iOS
   yarn ios

   # Android
   yarn android
   ```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
