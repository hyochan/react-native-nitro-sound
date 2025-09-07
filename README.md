# react-native-nitro-sound

[![yarn Version](http://img.shields.io/npm/v/react-native-nitro-sound.svg?style=flat-square)](https://npmjs.org/package/react-native-nitro-sound)
[![Weekly Downloads](http://img.shields.io/npm/dw/react-native-nitro-sound.svg?style=flat-square)](https://npmjs.org/package/react-native-nitro-sound)
[![Monthly Downloads](http://img.shields.io/npm/dm/react-native-nitro-sound.svg?style=flat-square)](https://npmjs.org/package/react-native-nitro-sound)
[![CI](https://github.com/hyochan/react-native-nitro-sound/actions/workflows/ci.yml/badge.svg)](https://github.com/hyochan/react-native-nitro-sound/actions/workflows/ci.yml)
[![publish-package](https://github.com/hyochan/react-native-nitro-sound/actions/workflows/publish-package.yml/badge.svg)](https://github.com/hyochan/react-native-nitro-sound/actions/workflows/publish-package.yml)
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue.svg?style=flat-square)](https://www.typescriptlang.org/)
[![MIT License](http://img.shields.io/npm/l/react-native-nitro-sound.svg?style=flat-square)](https://npmjs.org/package/react-native-nitro-sound)
[![code style: prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square)](https://github.com/prettier/prettier)

[![Platform - iOS](https://img.shields.io/badge/platform-iOS-blue.svg?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Platform - Android](https://img.shields.io/badge/platform-Android-green.svg?style=flat-square&logo=android&logoColor=white)](https://developer.android.com/)
[![Platform - Web](https://img.shields.io/badge/platform-Web-orange.svg?style=flat-square&logo=googlechrome&logoColor=white)](https://reactnative.dev/docs/react-native-web)

<img src="https://github.com/user-attachments/assets/81ce7b7b-0b7d-413b-8a26-505372349ecb" width="70%" alt="Logo" />

## Legacy Package (react-native-audio-recorder-player)

[![yarn Version](http://img.shields.io/npm/v/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![Downloads](http://img.shields.io/npm/dm/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![Weekly Downloads](http://img.shields.io/npm/dw/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)

## React Native Nitro Sound 🚀

**React Native Nitro Sound** is a high-performance audio recording and playback library built with [NitroModules](https://github.com/mrousavy/nitro), offering:

- **Zero Bridge Overhead**: Direct native module access for maximum performance
- **Full Type Safety**: TypeScript definitions generated from native specs
- **Synchronous Methods**: Where appropriate, for better developer experience
- **Event Listeners**: Native callbacks with type-safe event payloads
- **Cross-Platform Code Generation**: Automatic code generation for iOS (Swift) and Android (Kotlin)
- **Background Processing**: Recording operations now run in background threads to prevent UI blocking, requiring loading state management
- **Web Platform Support**: Full support for web browsers using Web Audio API and MediaRecorder API

### Requirements

- React Native: >= 0.79 (0.81 recommended)
- iOS: Deployment Target >= 13.0
  - Note: With RN 0.81+, build using Xcode >= 16.1 (toolchain requirement; iOS runtime minimum remains 13.0)
- Android: minSdk >= 24 (JDK 17 recommended; compileSdk 36 recommended)
- New Architecture: optional (Nitro works on both old and new arch)
- Expo SDK >= 50 (for Expo users)

## 🎉 React Native Nitro Sound - Reborn from React Native Audio Recorder Player

**React Native Nitro Sound** is the reborn version of [React Native Audio Recorder Player](https://www.npmjs.com/package/react-native-audio-recorder-player)!

For those unfamiliar, this was a beloved library with **40k+ weekly downloads** and **180k+ monthly downloads**. Now, this library embarks on a new journey with [NitroModules](https://github.com/mrousavy/nitro), starting fresh as **react-native-nitro-sound**.

As the creator of [Flutter Sound](https://pub.dev/packages/flutter_sound), the name 'Sound' feels much more familiar and close to my heart. This rebranding is not just a name change, but a commitment to actively maintain and evolve this library with even greater dedication.

Starting fresh with **version 1.0.0**, we're delivering a more powerful and stable audio solution. Special thanks to [@mrousavy](https://github.com/mrousavy) for creating this amazing technology! 🙏

Your continued support and interest mean the world to us!

---

This is a high-performance React Native module for audio recording and playback, now powered by [NitroModules](https://github.com/mrousavy/nitro) for direct native module access without bridge overhead. The library provides simple recorder and player functionalities for iOS, Android, and Web platforms with full TypeScript support and type safety.

> 🔴 **Critical**: Recording operations now run in background threads. **You MUST implement loading states** to handle the async delays, or your UI may appear unresponsive. See [Component Examples](#component-based-implementation) for proper implementation.

## Help Maintenance

This is one of those projects that brings me joy to work on. If you find it useful, consider buying me a coffee ☕️ — your support keeps me motivated!

<a href="https://www.buymeacoffee.com/hyochan" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/purple_img.png" alt="Buy Me A Coffee" style="height: auto !important;width: auto !important;" ></a>
[![Paypal](https://www.paypalobjects.com/webstatic/mktg/Logo/pp-logo-100px.png)](https://paypal.me/dooboolab)

## Preview

<img src="https://github.com/user-attachments/assets/02545c15-f41d-4186-be79-2a13fd67ccb2" width=800 alt="Screenshot"/>

<img src="https://github.com/user-attachments/assets/6d8a5a80-cd31-450f-b410-9b8f42ae8d03" width=800 alt="Screenshot2"/>

## Documentation & Resources

- 🔧 [NitroModules Documentation](https://github.com/mrousavy/nitro) - Learn about the underlying technology
- 📝 [Version 3 Release Note](https://medium.com/dooboolab/react-native-audio-player-and-recorder-v3-7697e25cd07)
- 📰 [Original Blog Post](https://medium.com/@dooboolab/react-native-audio-recorder-and-player-4aa5f26a666)

## Migration from react-native-audio-recorder-player

If you're migrating from `react-native-audio-recorder-player` (version 3.x or earlier), the API remains largely the same. Simply update your package name:

```diff
- import AudioRecorderPlayer from 'react-native-audio-recorder-player';
+ import Sound from 'react-native-nitro-sound';
```

## Getting started

1. **Install packages**:

   ```sh
   yarn add react-native-nitro-sound react-native-nitro-modules
   ```

   Or using npm:

   ```sh
   npm install react-native-nitro-sound react-native-nitro-modules
   ```

2. **Align React Native dependencies (recommended)**:

   ```sh
   npx @rnx-kit/align-deps --requirements react-native@0.81 --write
   ```

## Post Installation

After installing the packages, follow these steps:

1. **iOS Setup**:

   ```sh
   npx pod-install
   ```

   - If resolution fails, try `npx pod-install --repo-update`.
   - RN 0.81+ requires Xcode >= 16.1 to build.

2. **Android Setup**:
   No additional steps required. The module uses autolinking.

3. **Web Setup**:
   For React Native Web, install the additional dependency:

   ```sh
   yarn add react-native-web
   ```

   Then configure your webpack to include the web-specific implementation:

   ```js
   // webpack.config.js
   module.exports = {
     resolve: {
       alias: {
         'react-native': 'react-native-web',
       },
     },
   };
   ```

> **Note**: The `nitro-codegen` command is already run during the library's build process. You don't need to run it in your application.

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

On _Android_ you need to add permissions to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

Also, android above `Marshmallow` needs runtime permission to record audio. Below are two approaches:

**Minimal Approach (Recommended for Android 13+):**

```ts
if (Platform.OS === 'android') {
  try {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      {
        title: 'Audio Recording Permission',
        message: 'This app needs access to your microphone to record audio.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      }
    );

    if (granted === PermissionsAndroid.RESULTS.GRANTED) {
      console.log('Recording permission granted');
    } else {
      console.log('Recording permission denied');
      return;
    }
  } catch (err) {
    console.warn(err);
    return;
  }
}
```

**Full Permissions Approach (For older Android versions):**

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
      console.log('All permissions granted');
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

| Method                    |                      Param                       |      Return       | Description                                           |
| :------------------------ | :----------------------------------------------: | :---------------: | :---------------------------------------------------- |
| mmss                      |                 `number` seconds                 |     `string`      | Convert seconds to `minute:second` string             |
| mmssss                    |                 `number` seconds                 |     `string`      | Convert seconds to `minute:second:millisecond` string |
| setSubscriptionDuration   |                `number` duration                 |      `void`       | Set callback interval in ms (default 500ms)           |
| startRecorder             |       `string?` uri, `AudioSet?` audioSet,       | `Promise<string>` | Start recording with optional path and audio settings |
|                           |            `boolean?` meteringEnabled            |                   |                                                       |
| pauseRecorder             |                                                  | `Promise<string>` | Pause recording                                       |
| resumeRecorder            |                                                  | `Promise<string>` | Resume recording                                      |
| stopRecorder              |                                                  | `Promise<string>` | Stop recording and return file path                   |
| startPlayer               | `string?` uri, `Record<string, string>?` headers | `Promise<string>` | Start playback with optional URI and HTTP headers     |
| stopPlayer                |                                                  | `Promise<string>` | Stop playback                                         |
| pausePlayer               |                                                  | `Promise<string>` | Pause playback                                        |
| resumePlayer              |                                                  | `Promise<string>` | Resume playback                                       |
| seekToPlayer              |              `number` milliseconds               | `Promise<string>` | Seek to position in milliseconds                      |
| setVolume                 |                  `number` value                  | `Promise<string>` | Set volume (0.0 - 1.0)                                |
| setPlaybackSpeed          |                  `number` speed                  | `Promise<string>` | Set playback speed (0.5 - 2.0)                        |
| addRecordBackListener     |               `Function` callback                |      `void`       | Add recording progress listener                       |
| removeRecordBackListener  |                                                  |      `void`       | Remove recording progress listener                    |
| addPlayBackListener       |               `Function` callback                |      `void`       | Add playback progress listener                        |
| removePlayBackListener    |                                                  |      `void`       | Remove playback progress listener                     |
| addPlaybackEndListener    |               `Function` callback                |      `void`       | Add playback completion listener                      |
| removePlaybackEndListener |                                                  |      `void`       | Remove playback completion listener                   |

## Usage

### Basic Usage

```typescript
import Sound, {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
  AVEncodingOption,
  RecordBackType,
  PlayBackType,
} from 'react-native-nitro-sound';

// Sound is a singleton instance, use directly

// Recording
const onStartRecord = async () => {
  // Set up recording progress listener
  Sound.addRecordBackListener((e: RecordBackType) => {
    console.log('Recording progress:', e.currentPosition, e.currentMetering);
    setRecordSecs(e.currentPosition);
    setRecordTime(Sound.mmssss(Math.floor(e.currentPosition)));
  });

  const result = await Sound.startRecorder();
  console.log('Recording started:', result);
};

const onStopRecord = async () => {
  const result = await Sound.stopRecorder();
  Sound.removeRecordBackListener();
  console.log('Recording stopped:', result);
};

// Pause/Resume Recording
const onPauseRecord = async () => {
  await Sound.pauseRecorder();
  console.log('Recording paused');
};

const onResumeRecord = async () => {
  await Sound.resumeRecorder();
  console.log('Recording resumed');
};

// Playback
const onStartPlay = async () => {
  // Set up playback progress listener
  Sound.addPlayBackListener((e: PlayBackType) => {
    console.log('Playback progress:', e.currentPosition, e.duration);
    setCurrentPosition(e.currentPosition);
    setTotalDuration(e.duration);
    setPlayTime(Sound.mmssss(Math.floor(e.currentPosition)));
    setDuration(Sound.mmssss(Math.floor(e.duration)));
  });

  // Set up playback end listener
  Sound.addPlaybackEndListener((e: PlaybackEndType) => {
    console.log('Playback completed:', e);
    // Handle playback completion
    setIsPlaying(false);
    setCurrentPosition(0);
  });

  const result = await Sound.startPlayer();
  console.log('Playback started:', result);
};

const onPausePlay = async () => {
  await Sound.pausePlayer();
};

const onStopPlay = async () => {
  Sound.stopPlayer();
  Sound.removePlayBackListener();
  Sound.removePlaybackEndListener();
};

// Seeking
const seekTo = async (milliseconds: number) => {
  await Sound.seekToPlayer(milliseconds);
};

// Volume control
const setVolume = async (volume: number) => {
  await Sound.setVolume(volume); // 0.0 - 1.0
};

// Speed control
const setSpeed = async (speed: number) => {
  await Sound.setPlaybackSpeed(speed); // 0.5 - 2.0
};
```

### Modern API: Multiple Instances

```tsx
import { createSound } from 'react-native-nitro-sound';

// Create independent instances (recorder/player per instance)
const soundA = createSound();
const soundB = createSound();

await soundA.startPlayer('https://example.com/a.mp3');
await soundB.startPlayer('https://example.com/b.mp3');

// Control them independently
await soundA.pausePlayer();
await soundB.setVolume(0.5);

// Clean up when done
soundA.dispose();
soundB.dispose();
```

### React Hook API

```tsx
import { useSound } from 'react-native-nitro-sound';

export function Player() {
  const {
    sound,
    state,
    startPlayer,
    pausePlayer,
    resumePlayer,
    stopPlayer,
    seekToPlayer,
    mmssss,
  } = useSound({
    subscriptionDuration: 0.05, // 50ms updates
  });

  return (
    <View>
      <Text>
        {mmssss(Math.floor(state.currentPosition))} /{' '}
        {mmssss(Math.floor(state.duration))}
      </Text>
      <Button
        title="Play"
        onPress={() => startPlayer('https://example.com/audio.mp3')}
      />
      <Button title="Pause" onPress={pausePlayer} />
      <Button title="Resume" onPress={resumePlayer} />
      <Button title="Stop" onPress={stopPlayer} />
      <Button title="Seek 10s" onPress={() => seekToPlayer(10_000)} />
    </View>
  );
}
```

> Note: The default export remains a singleton for backward compatibility. Prefer `createSound()` and `useSound()` for new code and multiple instances.

### Audio Configuration

```typescript
const audioSet: AudioSet = {
  // iOS Settings
  AVSampleRateKeyIOS: 44100,
  AVFormatIDKeyIOS: AVEncodingOption.aac,
  AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
  AVNumberOfChannelsKeyIOS: 2,
  AVModeIOS: 'measurement', // Available options: 'gameChatAudio', 'measurement', 'moviePlayback', 'spokenAudio', 'videoChat', 'videoRecording', 'voiceChat', 'voicePrompt'

  // Android Settings
  AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
  AudioSourceAndroid: AudioSourceAndroidType.MIC,
};

const meteringEnabled = true; // Enable audio metering

const uri = await Sound.startRecorder(
  undefined, // Use default path
  audioSet,
  meteringEnabled
);
```

## Default Path

- Default path for android uri is `{cacheDir}/sound.mp4`.
- Default path for ios uri is `{cacheDir}/sound.m4a`.
- Default path for web: Files are stored as Blob URLs in memory.

> **Tip**: Store the file path returned by `startRecorder()` immediately for later use in playback or file management.

## Web Platform Support

### Features

- Audio recording using MediaRecorder API
- Audio playback using Web Audio API
- Support for common audio formats (depends on browser)
- Real-time playback progress updates
- Volume and speed control

### Limitations

- Recording format is browser-dependent (typically webm/opus)
- Some audio configuration options are not supported
- File paths are Blob URLs instead of file system paths
- Metering during recording is not currently supported

### Browser Compatibility

- Chrome/Edge: Full support
- Firefox: Full support
- Safari: Limited recording format support (may require polyfills)

## Component-Based Implementation

For better code organization, consider separating recording and playback into separate components:

### Important: Loading States

> **Note**: Starting from version 4.x, recording operations (start/stop) are processed in the background to prevent UI blocking. This means there's a slight delay between calling the method and the actual operation completing. **We strongly recommend implementing loading states** to provide better user experience.

### AudioRecorder Component with Loading States

```typescript
import React, { useState } from 'react';
import { View, Button, Text, ActivityIndicator } from 'react-native';
import Sound from 'react-native-nitro-sound';

export const AudioRecorder = ({ onRecordingComplete }) => {
  const [isRecording, setIsRecording] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [recordTime, setRecordTime] = useState('00:00:00');

  const onStartRecord = async () => {
    setIsLoading(true);
    try {
      const result = await Sound.startRecorder();
      Sound.addRecordBackListener((e) => {
        setRecordTime(Sound.mmssss(Math.floor(e.currentPosition)));
      });
      setIsRecording(true);
    } catch (error) {
      console.error('Failed to start recording:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const onStopRecord = async () => {
    setIsLoading(true);
    try {
      const result = await Sound.stopRecorder();
      Sound.removeRecordBackListener();
      setIsRecording(false);
      onRecordingComplete?.(result);
    } catch (error) {
      console.error('Failed to stop recording:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <View>
      <Text>{recordTime}</Text>
      <Button
        title={isRecording ? 'Stop Recording' : 'Start Recording'}
        onPress={isRecording ? onStopRecord : onStartRecord}
        disabled={isLoading}
      />
      {isLoading && <ActivityIndicator />}
    </View>
  );
};
```

### AudioPlayer Component with Loading States

```typescript
import React, { useState } from 'react';
import { View, Button, Text, ActivityIndicator } from 'react-native';
import Sound from 'react-native-nitro-sound';

export const AudioPlayer = ({ audioPath }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [playTime, setPlayTime] = useState('00:00:00');
  const [duration, setDuration] = useState('00:00:00');

  const onStartPlay = async () => {
    setIsLoading(true);
    try {
      const msg = await Sound.startPlayer(audioPath);
      Sound.addPlayBackListener((e) => {
        setPlayTime(Sound.mmssss(Math.floor(e.currentPosition)));
        setDuration(Sound.mmssss(Math.floor(e.duration)));
      });

      // Use the proper playback end listener
      Sound.addPlaybackEndListener((e) => {
        console.log('Playback completed', e);
        setIsPlaying(false);
        setPlayTime('00:00:00');
      });

      setIsPlaying(true);
    } catch (error) {
      console.error('Failed to start playback:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const onStopPlay = async () => {
    setIsLoading(true);
    try {
      await Sound.stopPlayer();
      Sound.removePlayBackListener();
      Sound.removePlaybackEndListener();
      setIsPlaying(false);
      setPlayTime('00:00:00');
      setDuration('00:00:00');
    } catch (error) {
      console.error('Failed to stop playback:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <View>
      <Text>{playTime} / {duration}</Text>
      <Button
        title={isPlaying ? 'Stop' : 'Play'}
        onPress={isPlaying ? onStopPlay : onStartPlay}
        disabled={!audioPath || isLoading}
      />
      {isLoading && <ActivityIndicator />}
    </View>
  );
};
```

## Example App

### Running the Example

Because this repo uses a Yarn workspace, run everything from the repository root.

1. Install dependencies and build the library:

   ```sh
   yarn
   yarn prepare
   ```

2. Start the development server:

   ```sh
   yarn start
   ```

3. Run on your platform:

   ```sh
   # iOS
   # First time on a new machine, you may need to install pods:
   (cd example/ios && pod install)
   yarn example ios

   # Android
   yarn example android
   ```

## Troubleshooting

### iOS Recording Error: "Unknown std::runtime_error"

If you encounter this error when trying to record on iOS:

1. **Ensure microphone permissions are properly configured** in your `Info.plist`:

   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>Your app needs microphone access to record audio</string>
   ```

2. **Clean and rebuild your iOS project**:

   ```sh
   cd ios
   rm -rf build Pods
   pod install
   cd ..
   yarn ios
   ```

3. **Make sure you're testing on a real device** if using the simulator doesn't work. Some audio features require real hardware.

4. **Verify the Nitro modules are properly linked** by checking that the `[NitroModules] 🔥 Sound is boosted by nitro!` message appears during `pod install`.

### Common Issues

- **"nitro-codegen" command not found**: This command is only needed when developing the library itself, not when using it in your app.
- **Module not found errors**: Make sure to run `pod install` after installing the package.
- **Android build issues**: Ensure your `minSdkVersion` is 24 or higher in `android/build.gradle`.
  - If you see `:react-native:generateCodegenSchemaFromJavaScript` failing, this comes from RN's Gradle plugin (not Nitro). Ensure RN >= 0.79 (0.81 recommended) and JDK 17, then align and clean:

    ```sh
    npx @rnx-kit/align-deps --requirements react-native@0.81 --write
    rm -rf node_modules android/.gradle
    yarn
    cd android && ./gradlew clean assembleDebug
    ```

### Clean Build Instructions

If you're experiencing build issues or runtime errors after updating the library:

#### iOS Clean Build

```sh
cd ios
rm -rf ~/Library/Caches/CocoaPods
rm -rf Pods
rm -rf ~/Library/Developer/Xcode/DerivedData/*
pod cache clean --all
pod install
cd ..
```

Then in Xcode:

1. Product → Clean Build Folder (⇧⌘K)
2. Product → Build (⌘B)

#### Android Clean Build

```sh
cd android
./gradlew clean
rm -rf ~/.gradle/caches/
cd ..
```

Then rebuild:

```sh
yarn android
# or
npx react-native run-android
```

#### Both Platforms

You can also try resetting Metro cache:

```sh
npx react-native start --reset-cache
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
