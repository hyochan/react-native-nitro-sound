import {
  ConfigPlugin,
  createRunOncePlugin,
  WarningAggregator,
  withAndroidManifest,
  withInfoPlist,
} from 'expo/config-plugins';

import * as pkg from '../../package.json';

// Global flag to prevent duplicate logs
let hasLoggedPluginExecution = false;

const withAudioRecorderPlayerAndroid: ConfigPlugin = (config) => {
  config = withAndroidManifest(config, (config) => {
    const manifest = config.modResults;
    if (!manifest.manifest['uses-permission']) {
      manifest.manifest['uses-permission'] = [];
    }

    const permissions = manifest.manifest['uses-permission'];

    // Required permissions for audio recording and storage
    const requiredPermissions = [
      'android.permission.RECORD_AUDIO',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_EXTERNAL_STORAGE',
    ];

    let addedPermissions: string[] = [];

    requiredPermissions.forEach((permission) => {
      const alreadyExists = permissions.some(
        (p) => p.$['android:name'] === permission,
      );
      if (!alreadyExists) {
        permissions.push({$: {'android:name': permission}});
        addedPermissions.push(permission);
      }
    });

    if (addedPermissions.length > 0 && !hasLoggedPluginExecution) {
      console.log(
        `✅ react-native-audio-recorder-player: Added Android permissions to AndroidManifest.xml:\n   ${addedPermissions.join('\n   ')}`,
      );
    } else if (!hasLoggedPluginExecution) {
      console.log(
        'ℹ️  react-native-audio-recorder-player: All required Android permissions already exist in AndroidManifest.xml',
      );
    }

    return config;
  });

  return config;
};

const withAudioRecorderPlayerIOS: ConfigPlugin = (config) => {
  config = withInfoPlist(config, (config) => {
    const infoPlist = config.modResults;

    // Add microphone usage description
    if (!infoPlist.NSMicrophoneUsageDescription) {
      infoPlist.NSMicrophoneUsageDescription =
        'This app needs access to your microphone to record audio.';

      if (!hasLoggedPluginExecution) {
        console.log(
          '✅ react-native-audio-recorder-player: Added NSMicrophoneUsageDescription to Info.plist',
        );
      }
    } else {
      if (!hasLoggedPluginExecution) {
        console.log(
          'ℹ️  react-native-audio-recorder-player: NSMicrophoneUsageDescription already exists in Info.plist',
        );
      }
    }

    return config;
  });

  return config;
};

const withAudioRecorderPlayer: ConfigPlugin<
  {
    microphonePermissionText?: string;
  } | void
> = (config, props) => {
  try {
    // Apply iOS microphone permission text if provided
    if (props?.microphonePermissionText) {
      config = withInfoPlist(config, (config) => {
        config.modResults.NSMicrophoneUsageDescription =
          props.microphonePermissionText;
        return config;
      });
    }

    // Apply Android configuration
    config = withAudioRecorderPlayerAndroid(config);

    // Apply iOS configuration
    config = withAudioRecorderPlayerIOS(config);

    // Set flag after first execution to prevent duplicate logs
    hasLoggedPluginExecution = true;

    return config;
  } catch (error) {
    WarningAggregator.addWarningAndroid(
      'react-native-audio-recorder-player',
      `react-native-audio-recorder-player plugin encountered an error: ${error}`,
    );
    console.error('react-native-audio-recorder-player plugin error:', error);
    return config;
  }
};

export default createRunOncePlugin(
  withAudioRecorderPlayer,
  pkg.name,
  pkg.version,
);

