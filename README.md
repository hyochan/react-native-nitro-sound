# react-native-audio-recorder-player

<img src="Logotype Primary.png" width="70%" height="70%" />

[![yarn Version](http://img.shields.io/npm/v/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![Downloads](http://img.shields.io/npm/dm/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![CI](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/ci.yml/badge.svg)](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/ci.yml)
[![publish-package](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/publish-package.yml/badge.svg)](https://github.com/hyochan/react-native-audio-recorder-player/actions/workflows/publish-package.yml)
![License](http://img.shields.io/npm/l/react-native-audio-recorder-player.svg?style=flat-square)
[![supports iOS](https://img.shields.io/badge/iOS-4630EB.svg?style=flat-square&logo=APPLE&labelColor=999999&logoColor=fff)](https://itunes.apple.com/app/apple-store/id982107779)
[![supports Android](https://img.shields.io/badge/Android-4630EB.svg?style=flat-square&logo=ANDROID&labelColor=A4C639&logoColor=fff)](https://play.google.com/store/apps/details?id=host.exp.exponent&referrer=www)
[![code style: prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square)](https://github.com/prettier/prettier)
[![LICENSE](http://img.shields.io/npm/l/@react-native-seoul/masonry-list.svg?style=flat-square)](https://npmjs.org/package/@react-native-seoul/masonry-list)

This is a react-native link module for audio recorder and player. This is not a playlist audio module and this library provides simple recorder and player functionalities for both `android` and `ios` platforms. This only supports default file extension for each platform. This module can also handle file from url.

## Preview

<img src="https://user-images.githubusercontent.com/27461460/117547014-3fe52000-b068-11eb-9f34-2bfc1e5092fd.gif" width=300/>

## Free read

- [Version 3 Release Note](https://medium.com/dooboolab/react-native-audio-player-and-recorder-v3-7697e25cd07)

- Happy [Blog](https://medium.com/@dooboolab/react-native-audio-recorder-and-player-4aa5f26a666).

## Breaking Changes

- From version `3.0.+`, a critical migration has been done. Current version is not much different from version `2.0.+` in usability, but there are many changes internally. Also note that it supports `iOS` platform version `10.0` or newer.

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
     };

     export type PlayBackType = {
       isMuted?: boolean;
       currentPosition: number;
       duration: number;
     };
     ```

  4. `subscriptionDuration` offset not defaults to `0.5` which is `500ms`.
     - Resolve [#273](https://github.com/hyochan/react-native-audio-recorder-player/issues/273)

- There has been vast improvements in [#114](https://github.com/dooboolab/react-native-audio-recorder-player/pull/114) which is released in `2.3.0`. We now support all `RN` versions without any version differentiating. See below installation guide for your understanding.

## Migration Guide

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

`$ yarn add react-native-audio-recorder-player`

## Installation

#### Using React Native >= 0.61

[iOS only]

```sh
npx pod-install
```

#### Using React Native < 0.60

`$ react-native link react-native-audio-recorder-player`

### Manual installation

#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-audio-recorder-player` and add `RNAudioRecorderPlayer.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNAudioRecorderPlayer.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainApplication.java`

- Add `import package com.dooboolab.audiorecorderplayer.RNAudioRecorderPlayerPackage;` to the imports at the top of the file
- Add `new RNAudioRecorderPlayerPackage()` to the list returned by the `getPackages()` method

2. Append the following lines to `android/settings.gradle`:
   ```
   include ':react-native-audio-recorder-player'
   project(':react-native-audio-recorder-player').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-audio-recorder-player/android')
   ```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
   ```
     compile project(':react-native-audio-recorder-player')
   ```

## Post installation

#### iOS

On _iOS_ you need to add a usage description to `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Give $(PRODUCT_NAME) permission to use your microphone. Your record wont be shared without your permission.</string>
```

Also, add [swift bridging header](https://stackoverflow.com/questions/31716413/xcode-not-automatically-creating-bridging-header) if you haven't created one for `swift` compatibility.

<img width="800" alt="1" src="https://user-images.githubusercontent.com/27461460/111863065-8be6e300-899c-11eb-8ad8-6811e0bd0fbd.png">

#### Android

On _Android_ you need to add a permission to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

Also, android above `Marshmallow` needs runtime permission to record audio. Using [react-native-permissions](https://github.com/yonahforst/react-native-permissions) will help you out with this problem. Below is sample usage before when before staring the recording.

```ts
if (Platform.OS === 'android') {
  try {
    const grants = await PermissionsAndroid.requestMultiple([
      PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
    ]);

    console.log('write external storage', grants);

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

Lastly, you need to enable `kotlin`. Please change add the line below in `android/build.gradle`.

```diff
buildscript {
  ext {
      buildToolsVersion = "29.0.3"
+     // Note: Below change is necessary for pause / resume audio feature. Not for Kotlin.
+     minSdkVersion = 24
      compileSdkVersion = 29
      targetSdkVersion = 29
+     kotlinVersion = '1.6.10'

      ndkVersion = "20.1.5948944"
  }
  repositories {
      google()
      jcenter()
  }
  dependencies {
      classpath("com.android.tools.build:gradle:4.2.2")
  }
...
```

## Methods

All methods are implemented with promises.

| Func                     |                        Param                        |      Return       | Description                                                                                                         |
| :----------------------- | :-------------------------------------------------: | :---------------: | :------------------------------------------------------------------------------------------------------------------ |
| mmss                     |                  `number` seconds                   |     `string`      | Convert seconds to `minute:second` string                                                                           |
| setSubscriptionDuration  |                                                     |      `void`       | Set default callback time when starting recorder or player. Default to `0.5` which is `500ms`                       |
| addRecordBackListener    |                 `Function` callBack                 |      `void`       | Get callback from native module. Will receive `currentPosition`, `currentMetering` (if configured in startRecorder) |
| removeRecordBackListener |                 `Function` callBack                 |      `void`       | Removes recordBack listener                                                                                         |
| addPlayBackListener      |                 `Function` callBack                 |      `void`       | Get callback from native module. Will receive `duration`, `currentPosition`                                         |
| removePlayBackListener   |                 `Function` callBack                 |      `void`       | Removes playback listener                                                                                           |
| startRecorder            |    `<string>` uri? `<boolean>` meteringEnabled?     |  `Promise<void>`  | Start recording. Not passing uri will save audio in default location.                                               |
| pauseRecorder            |                                                     | `Promise<string>` | Pause recording.                                                                                                    |
| resumeRecorder           |                                                     | `Promise<string>` | Resume recording.                                                                                                   |
| stopRecorder             |                                                     | `Promise<string>` | Stop recording.                                                                                                     |
| startPlayer              | `string` uri? `Record<string, string>` httpHeaders? | `Promise<string>` | Start playing. Not passing the param will play audio in default location.                                           |
| stopPlayer               |                                                     | `Promise<string>` | Stop playing.                                                                                                       |
| pausePlayer              |                                                     | `Promise<string>` | Pause playing.                                                                                                      |
| seekToPlayer             |                `number` milliseconds                | `Promise<string>` | Seek audio.                                                                                                         |
| setVolume                |                   `double` value                    | `Promise<string>` | Set volume of audio player (default 1.0, range: 0.0 ~ 1.0).                                                         |

## Able to customize recorded audio quality (from `2.3.0`)

```
interface AudioSet {
  AVSampleRateKeyIOS?: number;
  AVFormatIDKeyIOS?: AVEncodingType;
  AVModeIOS?: AVModeType;
  AVNumberOfChannelsKeyIOS?: number;
  AVEncoderAudioQualityKeyIOS?: AVEncoderAudioQualityIOSType;
  AudioSourceAndroid?: AudioSourceAndroidType;
  OutputFormatAndroid?: OutputFormatAndroidType;
  AudioEncoderAndroid?: AudioEncoderAndroidType;
}
```

> More description on each parameter types are described in `index.d.ts`. Below is an example code.

```ts
const audioSet: AudioSet = {
  AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
  AudioSourceAndroid: AudioSourceAndroidType.MIC,
  AVModeIOS: AVModeIOSOption.measurement,
  AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
  AVNumberOfChannelsKeyIOS: 2,
  AVFormatIDKeyIOS: AVEncodingOption.aac,
};
const meteringEnabled = false;

const uri = await this.audioRecorderPlayer.startRecorder(
  path,
  audioSet,
  meteringEnabled,
);

this.audioRecorderPlayer.addRecordBackListener((e: any) => {
  this.setState({
    recordSecs: e.currentPosition,
    recordTime: this.audioRecorderPlayer.mmssss(Math.floor(e.currentPosition)),
  });
});
```

## Default Path

- Default path for android uri is `{cacheDir}/sound.mp4`.
- Default path for ios uri is `{cacheDir}/sound.m4a`.

## Usage

```javascript
import AudioRecorderPlayer from 'react-native-audio-recorder-player';

const audioRecorderPlayer = new AudioRecorderPlayer();

onStartRecord = async () => {
  const result = await this.audioRecorderPlayer.startRecorder();
  this.audioRecorderPlayer.addRecordBackListener((e) => {
    this.setState({
      recordSecs: e.currentPosition,
      recordTime: this.audioRecorderPlayer.mmssss(
        Math.floor(e.currentPosition),
      ),
    });
    return;
  });
  console.log(result);
};

onStopRecord = async () => {
  const result = await this.audioRecorderPlayer.stopRecorder();
  this.audioRecorderPlayer.removeRecordBackListener();
  this.setState({
    recordSecs: 0,
  });
  console.log(result);
};

onStartPlay = async () => {
  console.log('onStartPlay');
  const msg = await this.audioRecorderPlayer.startPlayer();
  console.log(msg);
  this.audioRecorderPlayer.addPlayBackListener((e) => {
    this.setState({
      currentPositionSec: e.currentPosition,
      currentDurationSec: e.duration,
      playTime: this.audioRecorderPlayer.mmssss(Math.floor(e.currentPosition)),
      duration: this.audioRecorderPlayer.mmssss(Math.floor(e.duration)),
    });
    return;
  });
};

onPausePlay = async () => {
  await this.audioRecorderPlayer.pausePlayer();
};

onStopPlay = async () => {
  console.log('onStopPlay');
  this.audioRecorderPlayer.stopPlayer();
  this.audioRecorderPlayer.removePlayBackListener();
};
```

## TIPS

If you want to get actual uri from the record or play file to actually grab it and upload it to your bucket, just grab the resolved message when using `startPlay` or `startRecord` method like below.

To access the file with more reliability, please use [react-native-blob-util](https://www.npmjs.com/package/react-native-blob-util) or [react-native-file-access](https://github.com/alpha0010/react-native-file-access). See below for examples.

`react-native-blob-util`
```ts
import ReactNativeBlobUtil from 'react-native-blob-util'
...
const dirs = ReactNativeBlobUtil.fs.dirs;
const path = Platform.select({
  ios: 'hello.m4a',
  android: `${dirs.CacheDir}/hello.mp3`,
});

const uri = await audioRecorderPlayer.startRecord(path);
```

Also, above example helps you to setup manual path to record audio. Not giving path param will record in `default` path as mentioned above.

To pass in specific URI in IOS, you need to append `file://` to the path. As an example using [RFNS](https://github.com/itinance/react-native-fs).

```javascript
const dirs = RNFetchBlob.fs.dirs;
const path = Platform.select({
  ios: `file://${RNFS.DocumentDirectoryPath}/hello.m4a`,
  android: `${this.dirs.CacheDir}/hello.mp3`,
});

const uri = await audioRecorderPlayer.startRecord(path);
```

`react-native-file-access`
```ts
import { Dirs } from "react-native-file-access";
...
const path = Platform.select({
  ios: 'hello.m4a',
  android: `${Dirs.CacheDir}/hello.mp3`,
});

const uri = await audioRecorderPlayer.startRecord(path);
```



## Try yourself

1. Goto `Example` folder by running `cd Example`.
2. Run `yarn install && yarn start`.
3. Run `yarn ios` to run on ios simulator and `yarn android` to run on your android device.

## Special Thanks

[mansya](https://github.com/mansya) - logo designer.

## Help Maintenance

I've been maintaining quite many repos these days and burning out slowly. If you could help me cheer up, buying me a cup of coffee will make my life really happy and get much energy out of it.
<br/>
<a href="https://www.buymeacoffee.com/dooboolab" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/purple_img.png" alt="Buy Me A Coffee" style="height: auto !important;width: auto !important;" ></a>
[![Paypal](https://www.paypalobjects.com/webstatic/mktg/Logo/pp-logo-100px.png)](https://paypal.me/dooboolab)
