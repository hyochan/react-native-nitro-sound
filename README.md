# react-native-audio-recorder-player

<img src="Logotype Primary.png" width="70%" height="70%" />

[![Npm Version](http://img.shields.io/npm/v/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![Downloads](http://img.shields.io/npm/dm/react-native-audio-recorder-player.svg?style=flat-square)](https://npmjs.org/package/react-native-audio-recorder-player)
[![Build Status](https://travis-ci.com/dooboolab/react-native-audio-recorder-player.svg?branch=master)](https://travis-ci.com/dooboolab/react-native-audio-recorder-player) [![Greenkeeper badge](https://badges.greenkeeper.io/dooboolab/react-native-audio-recorder-player.svg)](https://greenkeeper.io/)
![License](http://img.shields.io/npm/l/react-native-audio-recorder-player.svg?style=flat-square)

This is a react-native link module for audio recorder and player. This is not a playlist audio module and this library provides simple recorder and player functionalities for both `android` and `ios` platforms. This only supports default file extension for each platform. This module can also handle file from url.

## Free read

- Happy [Blog](https://medium.com/@dooboolab/react-native-audio-recorder-and-player-4aa5f26a666).

## Breaking Changes

- There has been vast improvements in [#114](https://github.com/dooboolab/react-native-audio-recorder-player/pull/114) which is released in `2.3.0`. We now support all `RN` versions without any version differenciating. See below installation guide for your understanding.

## Preview

<img src="https://firebasestorage.googleapis.com/v0/b/flutterdart-5d354.appspot.com/o/react-native-audio-recorder-player.gif?alt=media&token=2bff9eeb-bab6-4265-918b-aa0c83ae0faf"/>

## Migration Guide

| 1._._                  | 2._._                     |
| ---------------------- | ------------------------- |
| `startRecord`          | `startRecorder`           |
| `stopRecord`           | `stopRecorder`            |
| `startPlay`            | `startPlayer`             |
| `stopPlay`             | `stopPlayer`              |
| `pausePlay`            | `pausePlayer`             |
| `resume`               | `resumePlayer`            |
| `seekTo`               | `seekToPlayer`            |
|                        | `setSubscriptionDuration` |
| `setRecordInterval`    | `addRecordBackListener`   |
| `removeRecordInterval` | ``                        |
|                        | `setVolume`               |

## Getting started

`$ npm install react-native-audio-recorder-player --save`

### Mostly automatic installation

#### Using React Native >= 0.60

Linking the package manually is not required anymore with [Autolinking](https://github.com/react-native-community/cli/blob/master/docs/autolinking.md).

- **iOS Platform:**

  `$ cd ios && pod install && cd ..` # CocoaPods on iOS needs this extra step

- **Android Platform with Android Support:**

  Using [Jetifier tool](https://github.com/mikehardy/jetifier) for backward-compatibility.

  Modify your **android/build.gradle** configuration:

  ```
  buildscript {
    ext {
      buildToolsVersion = "28.0.3"
      minSdkVersion = 16
      compileSdkVersion = 28
      targetSdkVersion = 28
      # Only using Android Support libraries
      supportLibVersion = "28.0.0"
    }
  ```

- **Android Platform with AndroidX:**

  Modify your **android/build.gradle** configuration:

  ```
  buildscript {
    ext {
      buildToolsVersion = "28.0.3"
      minSdkVersion = 16
      compileSdkVersion = 28
      targetSdkVersion = 28
      # Remove 'supportLibVersion' property and put specific versions for AndroidX libraries
      androidXAnnotation = "1.1.0"
      androidXBrowser = "1.0.0"
      // Put here other AndroidX dependencies
    }
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

- Add `import com.dooboolab.RNAudioRecorderPlayerPackage;` to the imports at the top of the file
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

### Post installation

On _iOS_ you need to add a usage description to `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This sample uses the microphone to record your speech and convert it to text.</string>
```

On _Android_ you need to add a permission to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Also, android above `Marshmallow` needs runtime permission to record audio. Using [react-native-permissions](https://github.com/yonahforst/react-native-permissions) will help you out with this problem. Below is sample usage before when started the recording.

```javascript
if (Platform.OS === 'android') {
  try {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      {
        title: 'Permissions for write access',
        message: 'Give permission to your storage to write a file',
        buttonPositive: 'ok',
      },
    );
    if (granted === PermissionsAndroid.RESULTS.GRANTED) {
      console.log('You can use the storage');
    } else {
      console.log('permission denied');
      return;
    }
  } catch (err) {
    console.warn(err);
    return;
  }
}
if (Platform.OS === 'android') {
  try {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      {
        title: 'Permissions for write access',
        message: 'Give permission to your storage to write a file',
        buttonPositive: 'ok',
      },
    );
    if (granted === PermissionsAndroid.RESULTS.GRANTED) {
      console.log('You can use the camera');
    } else {
      console.log('permission denied');
      return;
    }
  } catch (err) {
    console.warn(err);
    return;
  }
}
```

## Methods

All methods are implemented with promises.

| Func                  |        Param        |      Return       | Description                                                                  |
| :-------------------- | :--------------------: | :---------------: | :--------------------------------------------------------------------------- |
| mmss                  |  `number` seconds       |     `string`      | Convert seconds to `minute:second` string.                                   |
| addRecordBackListener |                         |  `Promise<void>`  | Set record interval in second.                                               |
| addPlayBackListener   | `Function` callBack     |      `void`       | Get callback from native module. Will receive `duration`, `current_position` |
| startRecorder         |   `<string>` uri?       |  `Promise<void>`  | Start recording. Not passing the param will save audio in default location.  |
| stopRecorder          |                         | `Promise<string>` | Stop recording.                                                              |
| startPlayer           |   `<string>` uri?       | `Promise<string>` | Start playing. Not passing the param will play audio in default location.    |
| stopPlayer            |                         | `Promise<string>` | Stop playing.                                                                |
| pausePlayer           |                         | `Promise<string>` | Pause playing.                                                               |
| seekToPlayer          |  `number` miliseconds   | `Promise<string>` | Seek audio.                                                                  |
| setVolume             |   `doulbe` value        | `Promise<string>` | Set volume of audio player (default 1.0, range: 0.0 ~ 1.0).                  |

## Customizing recorded audio quality (from `2.3.0`)

```
interface AudioSet {
  AVSampleRateKeyIOS?: number;
  AVFormatIDKeyIOS?: AVEncodingType;
  AVNumberOfChannelsKeyIOS?: number;
  AVEncoderAudioQualityKeyIOS?: AVEncoderAudioQualityIOSType;
  AudioSourceAndroid?: AudioSourceAndroidType;
  OutputFormatAndroid?: OutputFormatAndroidType;
  AudioEncoderAndroid?: AudioEncoderAndroidType;
}
```

> More description on each parameter types are described in `index.d.ts`. Below is an example code.

```
    const audioSet: AudioSet = {
      AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
      AudioSourceAndroid: AudioSourceAndroidType.MIC,
      AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
      AVNumberOfChannelsKeyIOS: 2,
      AVFormatIDKeyIOS: AVEncodingOption.aac,
    };
    const meteringEnabled = false; 

    const uri = await this.audioRecorderPlayer.startRecorder(path, meteringEnabled, audioSet);
    
    this.audioRecorderPlayer.addRecordBackListener((e: any) => {
      this.setState({
        recordSecs: e.current_position,
        recordTime: this.audioRecorderPlayer.mmssss(
          Math.floor(e.current_position),
        ),
      });
    });
```

## Default Path

- Default path for android uri is `sdcard/sound.mp4`.
- Default path for ios uri is `sound.m4a`.

## Usage

```javascript
import AudioRecorderPlayer from 'react-native-audio-recorder-player';

const audioRecorderPlayer = new AudioRecorderPlayer();

onStartRecord = async () => {
  const result = await this.audioRecorderPlayer.startRecorder();
  this.audioRecorderPlayer.addRecordBackListener((e) => {
    this.setState({
      recordSecs: e.current_position,
      recordTime: this.audioRecorderPlayer.mmssss(
        Math.floor(e.current_position),
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
    if (e.current_position === e.duration) {
      console.log('finished');
      this.audioRecorderPlayer.stopPlayer();
    }
    this.setState({
      currentPositionSec: e.current_position,
      currentDurationSec: e.duration,
      playTime: this.audioRecorderPlayer.mmssss(Math.floor(e.current_position)),
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

```javascript
const path = Platform.select({
  ios: 'hello.m4a',
  android: 'sdcard/hello.mp4', // should give extra dir name in android. Won't grant permission to the first level of dir.
});
const uri = await audioRecorderPlayer.startRecord(path);
```

Also, above example helps you to setup manual path to record audio. Not giving path param will record in `default` path as mentioned above.

## Try yourself

1. Goto `Example` folder by running `cd Example`.
2. Run `npm install && npm start`.
3. Run `npm run ios` to run on ios simulator and `npm run android` to run on your android device.

### TODO

- [ ] Better android permission handling
- [x] Volume Control
- [x] Sync timing for recorder callback handler

## Special Thanks

[mansya](https://github.com/mansya) - logo designer.

## Help Maintenance

I've been maintaining quite many repos these days and burning out slowly. If you could help me cheer up, buying me a cup of coffee will make my life really happy and get much energy out of it.
<br/>
<a href="https://www.buymeacoffee.com/dooboolab" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/purple_img.png" alt="Buy Me A Coffee" style="height: auto !important;width: auto !important;" ></a>
[![Paypal](https://www.paypalobjects.com/webstatic/mktg/Logo/pp-logo-100px.png)](https://paypal.me/dooboolab)
