# React Native Audio Recorder Player - Expo Example

This is an Expo example app demonstrating the usage of `react-native-audio-recorder-player` with the Expo config plugin.

## Features

- Audio recording with pause/resume functionality
- Audio playback with seek support
- Modern UI with visual feedback
- Automatic permission handling via Expo config plugin

## Setup

1. Install dependencies:
```bash
bun install
```

2. Run the app:
```bash
# iOS
bun ios

# Android
bun android
```

## Config Plugin

This example uses the Expo config plugin to automatically configure:

### Android
- `RECORD_AUDIO` permission
- `WRITE_EXTERNAL_STORAGE` permission
- `READ_EXTERNAL_STORAGE` permission

### iOS
- `NSMicrophoneUsageDescription` in Info.plist

The plugin is configured in `app.config.js`:

```javascript
plugins: [
  "../app.plugin.js",
  [
    "expo-media-library",
    {
      "photosPermission": "Allow $(PRODUCT_NAME) to access your photos.",
      "savePhotosPermission": "Allow $(PRODUCT_NAME) to save photos.",
      "isAccessMediaLocationEnabled": true
    }
  ]
]
```

## Permissions

The app uses `expo-media-library` for handling runtime permissions in a cross-platform way. Permissions are requested when the user first tries to record audio.

## File Storage

- **iOS**: Audio files are saved in the app's documents directory
- **Android**: Audio files are saved in the app's cache directory

## Usage

1. **Recording**:
   - Press "Record" to start recording
   - Press "Pause" to pause the recording
   - Press "Resume" to continue recording
   - Press "Stop" to finish recording

2. **Playback**:
   - After recording, press "Play" to listen to the recorded audio
   - Use the progress bar to seek to different positions
   - Press "Pause" to pause playback
   - Press "Resume" to continue playback
   - Press "Stop" to stop playback

The app displays the recording time and playback progress in real-time.