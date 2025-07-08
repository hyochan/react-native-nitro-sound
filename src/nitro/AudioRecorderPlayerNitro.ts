import { NitroModules } from 'react-native-nitro-modules';
import type { AudioRecorderPlayer as IAudioRecorderPlayer, AudioSet, RecordBackType, PlayBackType } from './specs/AudioRecorderPlayer.nitro';

/**
 * Audio recorder and player class using Nitro modules for performance
 */
export class AudioRecorderPlayerNitro {
  private static instance: AudioRecorderPlayerNitro;
  private nitroModule: IAudioRecorderPlayer;
  private recordBackListener?: () => void;
  private playBackListener?: () => void;
  private _isRecording = false;
  private _isPlaying = false;
  private _recordTime = '00:00:00';
  private _currentPositionSec = 0;
  private _currentDurationSec = 0;
  private _playTime = '00:00:00';
  private _duration = '00:00:00';

  constructor() {
    this.nitroModule = NitroModules.createHybridObject<IAudioRecorderPlayer>('AudioRecorderPlayer');
  }

  static getInstance(): AudioRecorderPlayerNitro {
    if (!AudioRecorderPlayerNitro.instance) {
      AudioRecorderPlayerNitro.instance = new AudioRecorderPlayerNitro();
    }
    return AudioRecorderPlayerNitro.instance;
  }

  /**
   * Convert milliseconds to mm:ss:ss format
   */
  mmssss = (milisecs: number): string => {
    const secs = Math.floor(milisecs / 1000);
    const minutes = Math.floor(secs / 60);
    const seconds = secs % 60;
    const miliseconds = Math.floor((milisecs % 1000) / 10);

    const minutesStr = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const secondsStr = seconds < 10 ? `0${seconds}` : `${seconds}`;
    const milisecondsStr = miliseconds < 10 ? `0${miliseconds}` : `${miliseconds}`;

    return `${minutesStr}:${secondsStr}:${milisecondsStr}`;
  };

  /**
   * Convert seconds to mm:ss format
   */
  mmss = (secs: number): string => {
    const minutes = Math.floor(secs / 60);
    const seconds = Math.floor(secs % 60);

    const minutesStr = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const secondsStr = seconds < 10 ? `0${seconds}` : `${seconds}`;

    return `${minutesStr}:${secondsStr}`;
  };

  /**
   * Set subscription duration for progress updates
   */
  setSubscriptionDuration = async (sec: number): Promise<void> => {
    await this.nitroModule.setSubscriptionDuration(sec);
  };

  /**
   * Start recording audio
   */
  startRecorder = async (
    uri?: string,
    audioSets?: AudioSet,
    meteringEnabled = false,
  ): Promise<string> => {
    const result = await this.nitroModule.startRecorder(uri, audioSets, meteringEnabled);
    this._isRecording = true;
    return result;
  };

  /**
   * Pause recording
   */
  pauseRecorder = async (): Promise<string> => {
    return await this.nitroModule.pauseRecorder();
  };

  /**
   * Resume recording
   */
  resumeRecorder = async (): Promise<string> => {
    return await this.nitroModule.resumeRecorder();
  };

  /**
   * Stop recording
   */
  stopRecorder = async (): Promise<string> => {
    const result = await this.nitroModule.stopRecorder();
    this._isRecording = false;
    return result;
  };

  /**
   * Start playing audio
   */
  startPlayer = async (
    uri?: string,
    httpHeaders?: Record<string, string>,
  ): Promise<string> => {
    const result = await this.nitroModule.startPlayer(uri, httpHeaders);
    this._isPlaying = true;
    return result;
  };

  /**
   * Pause playback
   */
  pausePlayer = async (): Promise<string> => {
    return await this.nitroModule.pausePlayer();
  };

  /**
   * Resume playback
   */
  resumePlayer = async (): Promise<string> => {
    return await this.nitroModule.resumePlayer();
  };

  /**
   * Stop playback
   */
  stopPlayer = async (): Promise<string> => {
    const result = await this.nitroModule.stopPlayer();
    this._isPlaying = false;
    return result;
  };

  /**
   * Seek to specific time in playback
   */
  seekToPlayer = async (time: number): Promise<string> => {
    return await this.nitroModule.seekToPlayer(time);
  };

  /**
   * Set playback volume
   */
  setVolume = async (volume: number): Promise<string> => {
    return await this.nitroModule.setVolume(volume);
  };

  /**
   * Set playback speed
   */
  setPlaybackSpeed = async (speed: number): Promise<string> => {
    return await this.nitroModule.setPlaybackSpeed(speed);
  };

  /**
   * Add recording progress listener
   */
  addRecordBackListener = (callback: (data: RecordBackType) => void): void => {
    if (this.recordBackListener) {
      this.recordBackListener();
    }

    // Use Nitro's event system
    this.recordBackListener = this.nitroModule.onRecordingProgress((data) => {
      this._recordTime = this.mmssss(data.currentPosition);
      this._currentPositionSec = data.currentPosition / 1000;
      callback(data);
    });
  };

  /**
   * Remove recording progress listener
   */
  removeRecordBackListener = (): void => {
    if (this.recordBackListener) {
      this.recordBackListener();
      this.recordBackListener = undefined;
    }
  };

  /**
   * Add playback progress listener
   */
  addPlayBackListener = (callback: (data: PlayBackType) => void): void => {
    if (this.playBackListener) {
      this.playBackListener();
    }

    // Use Nitro's event system
    this.playBackListener = this.nitroModule.onPlaybackProgress((data) => {
      this._playTime = this.mmssss(data.currentPosition);
      this._duration = this.mmssss(data.duration);
      this._currentPositionSec = data.currentPosition / 1000;
      this._currentDurationSec = data.duration / 1000;
      callback(data);
    });
  };

  /**
   * Remove playback progress listener
   */
  removePlayBackListener = (): void => {
    if (this.playBackListener) {
      this.playBackListener();
      this.playBackListener = undefined;
    }
  };

  // Getters for backward compatibility
  get isRecording(): boolean {
    return this._isRecording;
  }

  get isPlaying(): boolean {
    return this._isPlaying;
  }

  get recordTime(): string {
    return this._recordTime;
  }

  get currentPositionSec(): number {
    return this._currentPositionSec;
  }

  get currentDurationSec(): number {
    return this._currentDurationSec;
  }

  get playTime(): string {
    return this._playTime;
  }

  get duration(): string {
    return this._duration;
  }
}

// Export singleton instance for backward compatibility
const audioRecorderPlayer = AudioRecorderPlayerNitro.getInstance();
export default audioRecorderPlayer;