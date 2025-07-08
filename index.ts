// Re-export everything from Nitro implementation
export {AudioRecorderPlayerNitro as default} from './src/nitro/AudioRecorderPlayerNitro';
export {AudioRecorderPlayerNitro} from './src/nitro/AudioRecorderPlayerNitro';

// Re-export types and enums for backward compatibility
export {
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AudioEncoderAndroidType,
  AVEncodingOption,
  AVModeIOSOption,
  AVEncoderAudioQualityIOSType,
  AVLinearPCMBitDepthKeyIOSType,
} from './src/types';

export type {
  AudioSet,
  RecordBackType,
  PlayBackType,
} from './src/nitro/specs/AudioRecorderPlayer.nitro';

// For backward compatibility, export as AudioRecorderPlayer
export {AudioRecorderPlayerNitro as AudioRecorderPlayer} from './src/nitro/AudioRecorderPlayerNitro';
