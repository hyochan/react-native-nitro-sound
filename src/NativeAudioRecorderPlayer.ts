import type { TurboModule } from 'react-native';
import { TurboModuleRegistry, NativeModules } from 'react-native';

export enum AudioEncoderAndroidType {
  DEFAULT = 0,
  AMR_NB = 1,
  AMR_WB = 2,
  AAC = 3,
  HE_AAC = 4,
  AAC_ELD = 5,
  VORBIS = 6,
  OPUS = 7,
}

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
  RADIO_TUNER = 10,
  HOTWORD = 11,
}

export enum OutputFormatAndroidType {
  DEFAULT = 0,
  THREE_GPP = 1,
  MPEG_4 = 2,
  AMR_NB = 3,
  AMR_WB = 4,
  AAC_ADTS = 5,
  WEBM = 6,
  OGG = 7,
}

export enum AVEncoderAudioQualityIOSType {
  MIN = 0,
  LOW = 32,
  MEDIUM = 64,
  HIGH = 96,
  MAX = 127,
}

export interface AudioSet {
  AudioEncoderAndroid?: number;
  AudioSourceAndroid?: number;
  AVModeIOS?: number;
  AVEncoderAudioQualityKeyIOS?: number;
  AVNumberOfChannelsKeyIOS?: number;
  AVFormatIDKeyIOS?: number | string;
  AudioSampleRateAndroid?: number;
  AudioChannelsAndroid?: number;
  AudioEncodingBitRateAndroid?: number;
  IncludeBase64?: boolean;
  OutputFormatAndroid?: number;
}

export interface RecordBackType {
  isRecording?: boolean;
  currentPosition: number;
  currentMetering?: number;
}

export interface PlayBackType {
  isMuted?: boolean;
  currentPosition: number;
  duration: number;
}

export interface Spec extends TurboModule {
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
  startPlayer(uri?: string, httpHeaders?: Object): Promise<string>;
  stopPlayer(): Promise<string>;
  pausePlayer(): Promise<string>;
  resumePlayer(): Promise<string>;
  seekToPlayer(time: number): Promise<string>;
  setVolume(volume: number): Promise<string>;
  setPlaybackSpeed(speed: number): Promise<string>;

  // Subscription
  setSubscriptionDuration(sec: number): void;

  // Listeners
  addRecordBackListener(
    callback: (recordBackType: RecordBackType) => void
  ): void;
  removeRecordBackListener(): void;
  addPlayBackListener(callback: (playBackType: PlayBackType) => void): void;
  removePlayBackListener(): void;

  // Utility methods
  mmss(secs: number): string;
  mmssss(milisecs: number): string;
}

// Support both Old and New Architecture
const AudioRecorderPlayerModule = TurboModuleRegistry.get<Spec>(
  'AudioRecorderPlayer'
);

export default AudioRecorderPlayerModule || NativeModules.AudioRecorderPlayer;
