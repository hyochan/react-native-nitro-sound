export enum AudioSourceAndroidType {
  DEFAULT = 0,
  MIC,
  VOICE_UPLINK,
  VOICE_DOWNLINK,
  VOICE_CALL,
  CAMCORDER,
  VOICE_RECOGNITION,
  VOICE_COMMUNICATION,
  REMOTE_SUBMIX,
  UNPROCESSED,
  RADIO_TUNER = 1998,
  HOTWORD,
}

export enum OutputFormatAndroidType {
  DEFAULT = 0,
  THREE_GPP,
  MPEG_4,
  AMR_NB,
  AMR_WB,
  AAC_ADIF,
  AAC_ADTS,
  OUTPUT_FORMAT_RTP_AVP,
  MPEG_2_TS,
  WEBM,
}

export enum AudioEncoderAndroidType {
  DEFAULT = 0,
  AMR_NB,
  AMR_WB,
  AAC,
  HE_AAC,
  AAC_ELD,
  VORBIS,
}

export enum AVEncodingOption {
  lpcm = 'lpcm',
  ima4 = 'ima4',
  aac = 'aac',
  MAC3 = 'MAC3',
  MAC6 = 'MAC6',
  ulaw = 'ulaw',
  alaw = 'alaw',
  mp1 = 'mp1',
  mp2 = 'mp2',
  mp4 = 'mp4',
  alac = 'alac',
  amr = 'amr',
  flac = 'flac',
  opus = 'opus',
  wav = 'wav',
}

export type AVEncodingType =
  | AVEncodingOption.lpcm
  | AVEncodingOption.ima4
  | AVEncodingOption.aac
  | AVEncodingOption.MAC3
  | AVEncodingOption.MAC6
  | AVEncodingOption.ulaw
  | AVEncodingOption.alaw
  | AVEncodingOption.mp1
  | AVEncodingOption.mp2
  | AVEncodingOption.mp4
  | AVEncodingOption.alac
  | AVEncodingOption.amr
  | AVEncodingOption.flac
  | AVEncodingOption.opus
  | AVEncodingOption.wav;

export enum AVModeIOSOption {
  gamechat = 'gamechat',
  measurement = 'measurement',
  movieplayback = 'movieplayback',
  spokenaudio = 'spokenaudio',
  videochat = 'videochat',
  videorecording = 'videorecording',
  voicechat = 'voicechat',
  voiceprompt = 'voiceprompt',
}

export type AVModeIOSType =
  | AVModeIOSOption.gamechat
  | AVModeIOSOption.measurement
  | AVModeIOSOption.movieplayback
  | AVModeIOSOption.spokenaudio
  | AVModeIOSOption.videochat
  | AVModeIOSOption.videorecording
  | AVModeIOSOption.voicechat
  | AVModeIOSOption.voiceprompt;

export enum AVEncoderAudioQualityIOSType {
  min = 0,
  low = 32,
  medium = 64,
  high = 96,
  max = 127,
}

export enum AVLinearPCMBitDepthKeyIOSType {
  'bit8' = 8,
  'bit16' = 16,
  'bit24' = 24,
  'bit32' = 32,
}

export interface AudioSet {
  AVSampleRateKeyIOS?: number;
  AVFormatIDKeyIOS?: AVEncodingType;
  AVModeIOS?: AVModeIOSType;
  AVNumberOfChannelsKeyIOS?: number;
  AVEncoderAudioQualityKeyIOS?: AVEncoderAudioQualityIOSType;
  AudioSourceAndroid?: AudioSourceAndroidType;
  AVLinearPCMBitDepthKeyIOS?: AVLinearPCMBitDepthKeyIOSType;
  AVLinearPCMIsBigEndianKeyIOS?: boolean;
  AVLinearPCMIsFloatKeyIOS?: boolean;
  AVLinearPCMIsNonInterleavedIOS?: boolean;
  AVEncoderBitRateKeyIOS?: number;
  OutputFormatAndroid?: OutputFormatAndroidType;
  AudioEncoderAndroid?: AudioEncoderAndroidType;
  AudioEncodingBitRateAndroid?: number;
  AudioSamplingRateAndroid?: number;
  AudioChannelsAndroid?: number;
}

export type RecordBackType = {
  isRecording?: boolean;
  currentPosition: number;
  currentMetering?: number;
};

export type PlayBackType = {
  isMuted?: boolean;
  currentPosition: number;
  duration: number;
};
