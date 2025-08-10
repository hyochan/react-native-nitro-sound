// Web stub for NativeAudioRecorderPlayer
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

// Web doesn't have native modules, return null
export default null;
