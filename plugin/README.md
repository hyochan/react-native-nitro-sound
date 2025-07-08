# Expo Config Plugin for react-native-audio-recorder-player

This plugin automatically configures your Expo project for using react-native-audio-recorder-player.

## What it does

### Android
- Adds required permissions to AndroidManifest.xml:
  - `android.permission.RECORD_AUDIO`
  - `android.permission.WRITE_EXTERNAL_STORAGE`
  - `android.permission.READ_EXTERNAL_STORAGE`

### iOS
- Adds `NSMicrophoneUsageDescription` to Info.plist

## Usage

In your `app.json` or `app.config.js`:

```json
{
  "expo": {
    "plugins": [
      "react-native-audio-recorder-player"
    ]
  }
}
```

Or with custom microphone permission text:

```json
{
  "expo": {
    "plugins": [
      [
        "react-native-audio-recorder-player",
        {
          "microphonePermissionText": "This app needs access to your microphone to record audio messages."
        }
      ]
    ]
  }
}
```

## Build

To build the plugin:

```bash
cd plugin
npm install
npm run build
```