import {
  type ConfigPlugin,
  createRunOncePlugin,
  WarningAggregator,
  withAndroidManifest,
  withInfoPlist,
} from 'expo/config-plugins';

import { version } from './version';

const pkg = {
  name: 'react-native-nitro-sound',
  version,
};

// Global flag to prevent duplicate logs
let hasLoggedPluginExecution = false;

const withSoundAndroid: ConfigPlugin = (config: any) => {
  config = withAndroidManifest(config, (c: any) => {
    const manifest = c.modResults;
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
        (p: any) => p.$['android:name'] === permission
      );
      if (!alreadyExists) {
        permissions.push({ $: { 'android:name': permission } });
        addedPermissions.push(permission);
      }
    });

    if (addedPermissions.length > 0 && !hasLoggedPluginExecution) {
      console.log(
        `✅ react-native-nitro-sound: Added Android permissions to AndroidManifest.xml:\n   ${addedPermissions.join('\n   ')}`
      );
    } else if (!hasLoggedPluginExecution) {
      console.log(
        'ℹ️  react-native-nitro-sound: All required Android permissions already exist in AndroidManifest.xml'
      );
    }

    return c;
  });

  return config;
};

const withSoundIOS: ConfigPlugin = (config: any) => {
  config = withInfoPlist(config, (c: any) => {
    const infoPlist = c.modResults;

    // Add microphone usage description
    if (!infoPlist.NSMicrophoneUsageDescription) {
      infoPlist.NSMicrophoneUsageDescription =
        'This app needs access to your microphone to record audio.';

      if (!hasLoggedPluginExecution) {
        console.log(
          '✅ react-native-nitro-sound: Added NSMicrophoneUsageDescription to Info.plist'
        );
      }
    } else {
      if (!hasLoggedPluginExecution) {
        console.log(
          'ℹ️  react-native-nitro-sound: NSMicrophoneUsageDescription already exists in Info.plist'
        );
      }
    }

    return c;
  });

  return config;
};

const withSound: ConfigPlugin<
  {
    microphonePermissionText?: string;
  } | void
> = (config: any, props?: any) => {
  try {
    // Apply iOS microphone permission text if provided
    if (props?.microphonePermissionText) {
      config = withInfoPlist(config, (c: any) => {
        c.modResults.NSMicrophoneUsageDescription =
          props.microphonePermissionText;
        return c;
      });
    }

    // Apply Android configuration
    config = withSoundAndroid(config);

    // Apply iOS configuration
    config = withSoundIOS(config);

    // Set flag after first execution to prevent duplicate logs
    hasLoggedPluginExecution = true;

    return config;
  } catch (error) {
    WarningAggregator.addWarningAndroid(
      'react-native-nitro-sound',
      `react-native-nitro-sound plugin encountered an error: ${error}`
    );
    console.error('react-native-nitro-sound plugin error:', error);
    return config;
  }
};

export default createRunOncePlugin(withSound, pkg.name, pkg.version);
