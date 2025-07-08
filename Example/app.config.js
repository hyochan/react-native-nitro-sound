export default {
  expo: {
    name: 'Audio Recorder Player Example',
    slug: 'audio-recorder-player-example',
    version: '1.0.0',
    orientation: 'portrait',
    icon: './assets/icon.png',
    userInterfaceStyle: 'light',
    newArchEnabled: true,
    splash: {
      image: './assets/splash-icon.png',
      resizeMode: 'contain',
      backgroundColor: '#ffffff',
    },
    ios: {
      supportsTablet: true,
      bundleIdentifier: 'com.dooboolab.audiorecorderplayer',
    },
    android: {
      adaptiveIcon: {
        foregroundImage: './assets/adaptive-icon.png',
        backgroundColor: '#ffffff',
      },
      package: 'com.dooboolab.audiorecorderplayer',
    },
    web: {
      favicon: './assets/favicon.png',
    },
    plugins: [
      '../app.plugin.js',
      [
        'expo-media-library',
        {
          photosPermission: 'Allow $(PRODUCT_NAME) to access your photos.',
          savePhotosPermission: 'Allow $(PRODUCT_NAME) to save photos.',
          isAccessMediaLocationEnabled: true,
        },
      ],
    ],
  },
};
