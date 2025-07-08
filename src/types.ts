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
  UNUSED,
  OGG,
}

export enum AudioEncoderAndroidType {
  DEFAULT = 0,
  AMR_NB,
  AMR_WB,
  AAC,
  HE_AAC,
  AAC_ELD,
  VORBIS,
  OPUS,
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
  alac = 'alac',
  amr = 'amr',
  flac = 'flac',
  opus = 'opus',
  wav = 'wav',
}

export enum AVModeIOSOption {
  gamechat = 'AVAudioSessionModeGameChat',
  measurement = 'AVAudioSessionModeMeasurement',
  movieplayback = 'AVAudioSessionModeMoviePlayback',
  spokenaudio = 'AVAudioSessionModeSpokenAudio',
  videochat = 'AVAudioSessionModeVideoChat',
  videorecording = 'AVAudioSessionModeVideoRecording',
  voicechat = 'AVAudioSessionModeVoiceChat',
  voiceprompt = 'AVAudioSessionModeVoicePrompt',
}

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