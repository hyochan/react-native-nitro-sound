import type {
  AudioSet,
  RecordBackType,
  PlayBackType,
} from './NativeAudioRecorderPlayer';

export type { AudioSet, RecordBackType, PlayBackType };
export {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AVEncoderAudioQualityIOSType,
} from './NativeAudioRecorderPlayer';

export interface PlaybackEndType {
  finished: boolean;
  duration?: number;
  currentPosition?: number;
}

class AudioRecorderPlayerImpl {
  // Recording methods
  async startRecorder(
    _uri?: string,
    _audioSets?: AudioSet,
    _meteringEnabled?: boolean
  ): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async pauseRecorder(): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async resumeRecorder(): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async stopRecorder(): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  // Playback methods
  async startPlayer(
    _uri?: string,
    _httpHeaders?: Record<string, string>
  ): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async stopPlayer(): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async pausePlayer(): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async resumePlayer(): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async seekToPlayer(_time: number): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async setVolume(_volume: number): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  async setPlaybackSpeed(_playbackSpeed: number): Promise<string> {
    console.warn('AudioRecorderPlayer is not supported on web');
    return Promise.resolve('');
  }

  // Subscription
  setSubscriptionDuration(_sec: number): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  // Listeners
  addRecordBackListener(
    _callback: (recordingMeta: RecordBackType) => void
  ): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  removeRecordBackListener(): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  addPlayBackListener(_callback: (playbackMeta: PlayBackType) => void): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  removePlayBackListener(): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  addPlaybackEndListener(
    _callback: (playbackEndMeta: PlaybackEndType) => void
  ): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  removePlaybackEndListener(): void {
    console.warn('AudioRecorderPlayer is not supported on web');
  }

  // Utility methods
  mmss(secs: number): string {
    const seconds = Math.floor(secs);
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
  }

  mmssss(milisecs: number): string {
    const totalSeconds = Math.floor(milisecs / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const milliseconds = Math.floor((milisecs % 1000) / 10);
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}:${milliseconds.toString().padStart(2, '0')}`;
  }
}

// Create singleton instance
const AudioRecorderPlayer = new AudioRecorderPlayerImpl();

export default AudioRecorderPlayer;
