import type { HybridObject } from 'react-native-nitro-modules'

export interface AudioSet {
  AudioSourceAndroid?: number
  OutputFormatAndroid?: number
  AudioEncoderAndroid?: number
  AudioSamplingRateAndroid?: number
  AudioEncodingBitRateAndroid?: number
  AudioChannelsAndroid?: number
  AVEncoderAudioQualityKeyIOS?: number
  AVFormatIDKeyIOS?: string
  AVNumberOfChannelsKeyIOS?: number
  AVSampleRateKeyIOS?: number
  AVModeIOS?: string
  AVLinearPCMBitDepthKeyIOS?: number
  AVLinearPCMIsFloatKeyIOS?: boolean
  AVLinearPCMIsBigEndianKeyIOS?: boolean
  AVLinearPCMIsNonInterleavedIOS?: boolean
  includeBase64?: boolean
}

export interface RecordBackType {
  isRecording: boolean
  currentPosition: number
  currentMetering?: number
}

export interface PlayBackType {
  isMuted: boolean
  currentPosition: number
  duration: number
  isFinished: boolean
}

export interface AudioRecorderPlayer extends HybridObject<{ ios: 'swift', android: 'kotlin' }> {
  // Recording methods
  startRecorder(uri?: string, audioSets?: AudioSet, meteringEnabled?: boolean): Promise<string>
  pauseRecorder(): Promise<string>
  resumeRecorder(): Promise<string>
  stopRecorder(): Promise<string>
  
  // Playback methods
  startPlayer(uri?: string, httpHeaders?: Record<string, string>): Promise<string>
  pausePlayer(): Promise<string>
  resumePlayer(): Promise<string>
  stopPlayer(): Promise<string>
  seekToPlayer(time: number): Promise<string>
  setVolume(volume: number): Promise<string>
  setPlaybackSpeed(playbackSpeed: number): Promise<string>
  
  // Subscription
  setSubscriptionDuration(sec: number): Promise<string>
  
  // Event listeners
  onRecordingProgress(callback: (data: RecordBackType) => void): () => void
  onPlaybackProgress(callback: (data: PlayBackType) => void): () => void
}