import type { HybridObject } from 'react-native-nitro-modules';

// Enums
export enum AudioSourceAndroidType {
  DEFAULT = 0,
  MIC = 1,
  VOICE_UPLINK = 2,
  VOICE_DOWNLINK = 3,
  VOICE_CALL = 4,
  CAMCORDER = 5,
  VOICE_RECOGNITION = 6,
  VOICE_COMMUNICATION = 7,
  REMOTE_SUBMIX = 8,
  UNPROCESSED = 9,
  RADIO_TUNER = 1998,
  HOTWORD = 1999,
}

export enum OutputFormatAndroidType {
  DEFAULT = 0,
  THREE_GPP = 1,
  MPEG_4 = 2,
  AMR_NB = 3,
  AMR_WB = 4,
  AAC_ADIF = 5,
  AAC_ADTS = 6,
  OUTPUT_FORMAT_RTP_AVP = 7,
  MPEG_2_TS = 8,
  WEBM = 9,
}

export enum AudioEncoderAndroidType {
  DEFAULT = 0,
  AMR_NB = 1,
  AMR_WB = 2,
  AAC = 3,
  HE_AAC = 4,
  AAC_ELD = 5,
  VORBIS = 6,
}

export type AVEncodingOption =
  | 'lpcm'
  | 'ima4'
  | 'aac'
  | 'MAC3'
  | 'MAC6'
  | 'ulaw'
  | 'alaw'
  | 'mp1'
  | 'mp2'
  | 'mp4'
  | 'alac'
  | 'amr'
  | 'flac'
  | 'opus';

export type AVModeIOSOption =
  | 'gameChatAudio'
  | 'videoRecording'
  | 'voiceChat'
  | 'videoChat';

export enum AVEncoderAudioQualityIOSType {
  min = 0,
  low = 0x20,
  medium = 0x40,
  high = 0x60,
  max = 0x7f,
}

export enum AVLinearPCMBitDepthKeyIOSType {
  bit8 = 8,
  bit16 = 16,
  bit24 = 24,
  bit32 = 32,
}

// Types
export type AudioQualityType = 'low' | 'medium' | 'high';

// Interfaces
export interface AudioSet {
  // Android settings
  AudioSourceAndroid?: AudioSourceAndroidType;
  OutputFormatAndroid?: OutputFormatAndroidType;
  AudioEncoderAndroid?: AudioEncoderAndroidType;

  // iOS settings
  AVEncoderAudioQualityKeyIOS?: AVEncoderAudioQualityIOSType;
  AVModeIOS?: AVModeIOSOption;
  AVEncodingOptionIOS?: AVEncodingOption;
  AVFormatIDKeyIOS?: AVEncodingOption;
  AVNumberOfChannelsKeyIOS?: number;
  AVLinearPCMBitDepthKeyIOS?: AVLinearPCMBitDepthKeyIOSType;
  AVLinearPCMIsBigEndianKeyIOS?: boolean;
  AVLinearPCMIsFloatKeyIOS?: boolean;
  AVLinearPCMIsNonInterleavedIOS?: boolean;
  AVSampleRateKeyIOS?: number;

  // Common settings
  AudioQuality?: AudioQualityType;
  AudioChannels?: number;
  AudioSamplingRate?: number;
  AudioEncodingBitRate?: number;
  IncludeBase64?: boolean;
}

export interface RecordBackType {
  isRecording?: boolean;
  currentPosition: number;
  currentMetering?: number;
  recordSecs?: number;
}

export interface PlayBackType {
  isMuted?: boolean;
  duration: number;
  currentPosition: number;
}

export interface AudioRecorderPlayer
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  // Recording methods
  startRecorder(
    uri?: string,
    audioSets?: AudioSet,
    meteringEnabled?: boolean
  ): Promise<string>;
  pauseRecorder(): Promise<string>;
  resumeRecorder(): Promise<string>;
  stopRecorder(): Promise<string>;

  // Playback methods
  startPlayer(
    uri?: string,
    httpHeaders?: Record<string, string>
  ): Promise<string>;
  stopPlayer(): Promise<string>;
  pausePlayer(): Promise<string>;
  resumePlayer(): Promise<string>;
  seekToPlayer(time: number): Promise<string>;
  setVolume(volume: number): Promise<string>;
  setPlaybackSpeed(playbackSpeed: number): Promise<string>;

  // Subscription
  setSubscriptionDuration(sec: number): void;

  // Listeners
  addRecordBackListener(
    callback: (recordingMeta: RecordBackType) => void
  ): void;
  removeRecordBackListener(): void;
  addPlayBackListener(callback: (playbackMeta: PlayBackType) => void): void;
  removePlayBackListener(): void;

  // Utility methods
  mmss(secs: number): string;
  mmssss(milisecs: number): string;
}
