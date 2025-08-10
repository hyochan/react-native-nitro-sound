import { NativeEventEmitter, NativeModules } from 'react-native';
import NativeAudioRecorderPlayer from './NativeAudioRecorderPlayer';
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
  private eventEmitter!: NativeEventEmitter;
  private recordBackSubscription: any;
  private playBackSubscription: any;

  constructor() {
    // Create event emitter for both iOS and Android
    if (NativeModules.AudioRecorderPlayer) {
      this.eventEmitter = new NativeEventEmitter(
        NativeModules.AudioRecorderPlayer
      );
    }
  }

  // Recording methods
  async startRecorder(
    uri?: string,
    audioSets?: AudioSet,
    meteringEnabled?: boolean
  ): Promise<string> {
    return NativeAudioRecorderPlayer.startRecorder(
      uri,
      audioSets,
      meteringEnabled
    );
  }

  async pauseRecorder(): Promise<string> {
    return NativeAudioRecorderPlayer.pauseRecorder();
  }

  async resumeRecorder(): Promise<string> {
    return NativeAudioRecorderPlayer.resumeRecorder();
  }

  async stopRecorder(): Promise<
    string | { filePath: string; duration: number }
  > {
    return NativeAudioRecorderPlayer.stopRecorder();
  }

  // Playback methods
  async startPlayer(
    uri?: string,
    httpHeaders?: Record<string, string>
  ): Promise<string> {
    return NativeAudioRecorderPlayer.startPlayer(uri, httpHeaders);
  }

  async stopPlayer(): Promise<string> {
    return NativeAudioRecorderPlayer.stopPlayer();
  }

  async pausePlayer(): Promise<string> {
    return NativeAudioRecorderPlayer.pausePlayer();
  }

  async resumePlayer(): Promise<string> {
    return NativeAudioRecorderPlayer.resumePlayer();
  }

  async seekToPlayer(time: number): Promise<string> {
    return NativeAudioRecorderPlayer.seekToPlayer(time);
  }

  async setVolume(volume: number): Promise<string> {
    return NativeAudioRecorderPlayer.setVolume(volume);
  }

  async setPlaybackSpeed(playbackSpeed: number): Promise<string> {
    return NativeAudioRecorderPlayer.setPlaybackSpeed(playbackSpeed);
  }

  // Subscription
  setSubscriptionDuration(sec: number): void {
    NativeAudioRecorderPlayer.setSubscriptionDuration(sec);
  }

  // Listeners
  private playbackEndSubscription: any;

  addRecordBackListener(
    callback: (recordingMeta: RecordBackType) => void
  ): void {
    // Remove existing subscription if any
    if (this.recordBackSubscription) {
      this.recordBackSubscription.remove();
    }

    // Set up event listener for both iOS and Android
    if (this.eventEmitter) {
      this.recordBackSubscription = this.eventEmitter.addListener(
        'rn-recordback',
        callback
      );
    }

    // Still call native method for compatibility
    NativeAudioRecorderPlayer.addRecordBackListener(callback);
  }

  removeRecordBackListener(): void {
    // Remove event subscription
    if (this.recordBackSubscription) {
      this.recordBackSubscription.remove();
      this.recordBackSubscription = null;
    }

    NativeAudioRecorderPlayer.removeRecordBackListener();
  }

  addPlayBackListener(callback: (playbackMeta: PlayBackType) => void): void {
    // Remove existing subscription if any
    if (this.playBackSubscription) {
      this.playBackSubscription.remove();
    }

    // Set up event listener for both iOS and Android
    if (this.eventEmitter) {
      this.playBackSubscription = this.eventEmitter.addListener(
        'rn-playback',
        callback
      );
    }

    // Still call native method for compatibility
    NativeAudioRecorderPlayer.addPlayBackListener(callback);
  }

  removePlayBackListener(): void {
    // Remove event subscription
    if (this.playBackSubscription) {
      this.playBackSubscription.remove();
      this.playBackSubscription = null;
    }

    NativeAudioRecorderPlayer.removePlayBackListener();
  }

  addPlaybackEndListener(
    callback: (playbackEndMeta: PlaybackEndType) => void
  ): void {
    // Remove existing subscription if any
    if (this.playbackEndSubscription) {
      this.playbackEndSubscription.remove();
    }

    // Set up event listener for both iOS and Android
    if (this.eventEmitter) {
      this.playbackEndSubscription = this.eventEmitter.addListener(
        'rn-playback-end',
        callback
      );
    }
  }

  removePlaybackEndListener(): void {
    // Remove event subscription
    if (this.playbackEndSubscription) {
      this.playbackEndSubscription.remove();
      this.playbackEndSubscription = null;
    }
  }

  // Utility methods
  mmss(secs: number): string {
    return NativeAudioRecorderPlayer.mmss(secs);
  }

  mmssss(milisecs: number): string {
    return NativeAudioRecorderPlayer.mmssss(milisecs);
  }
}

// Create singleton instance
const AudioRecorderPlayer = new AudioRecorderPlayerImpl();

export default AudioRecorderPlayer;
