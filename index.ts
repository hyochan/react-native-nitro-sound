// Re-export the default instance and types from the main implementation
export { default } from './src/index';
export * from './src/index';

// Re-export types from the nitro module
export type {
  AudioSet,
  RecordBackType,
  PlayBackType,
  AVEncodingOption,
  AVModeIOSOption,
} from './src/specs/AudioRecorderPlayer.nitro';

export {
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AudioEncoderAndroidType,
  AVEncoderAudioQualityIOSType,
  AVLinearPCMBitDepthKeyIOSType,
} from './src/specs/AudioRecorderPlayer.nitro';
