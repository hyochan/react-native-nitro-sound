// Re-export the default instance and types from the main implementation
export { default } from './src/index';
export * from './src/index';

// Re-export types from the nitro module
export type {
  AudioSet,
  RecordBackType,
  PlayBackType,
} from './src/AudioRecorderPlayer.nitro';

export {
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AudioEncoderAndroidType,
  type AVEncodingOption,
  type AVModeIOSOption,
  AVEncoderAudioQualityIOSType,
  AVLinearPCMBitDepthKeyIOSType,
} from './src/AudioRecorderPlayer.nitro';
