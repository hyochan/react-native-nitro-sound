import type {EmitterSubscription} from 'react-native';
import {
  DeviceEventEmitter,
  NativeEventEmitter,
  NativeModules,
  Platform,
} from 'react-native';

import {
  AVEncoderAudioQualityIOSType,
  AVEncodingOption,
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AudioSet,
  PlayBackType,
  RecordBackType,
  Status,
  pad,
} from './types';
import {AudioRecorderPlayerFC} from './index.fc';
export {
  AVEncoderAudioQualityIOSType,
  AVEncodingOption,
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AudioSet,
  PlayBackType,
  RecordBackType,
  Status,
  pad,
};
export {AudioRecorderPlayerFC};

const {RNAudioRecorderPlayer} = NativeModules;

class AudioRecorderPlayer {
  private _isRecording: boolean;
  private _isPlaying: boolean;
  private _hasPaused: boolean;
  private _hasPausedRecord: boolean;
  private _isStopped: boolean;
  private _recorderSubscription: EmitterSubscription;
  private _playerSubscription: EmitterSubscription;
  private _playerCallback: (event: PlayBackType) => void;

  mmss = (secs: number): string => {
    let minutes = Math.floor(secs / 60);

    secs = secs % 60;
    minutes = minutes % 60;

    return pad(minutes) + ':' + pad(secs);
  };

  mmssss = (milisecs: number): string => {
    const secs = Math.floor(milisecs / 1000);
    const minutes = Math.floor(secs / 60);
    const seconds = secs % 60;
    const miliseconds = Math.floor((milisecs % 1000) / 10);

    return pad(minutes) + ':' + pad(seconds) + ':' + pad(miliseconds);
  };

  /**
   * Set listerner from native module for recorder.
   * @returns {callBack((e: RecordBackType): void)}
   */

  addRecordBackListener = (
    callback: (recordingMeta: RecordBackType) => void,
  ): void => {
    if (Platform.OS === 'android') {
      this._recorderSubscription = DeviceEventEmitter.addListener(
        'rn-recordback',
        callback,
      );
    } else {
      const myModuleEvt = new NativeEventEmitter(RNAudioRecorderPlayer);

      this._recorderSubscription = myModuleEvt.addListener(
        'rn-recordback',
        callback,
      );
    }
  };

  /**
   * Remove listener for recorder.
   * @returns {void}
   */
  removeRecordBackListener = (): void => {
    if (this._recorderSubscription) {
      this._recorderSubscription.remove();
      this._recorderSubscription = null;
    }
  };

  /**
   * Set listener from native module for player.
   * @returns {callBack((e: PlayBackType): void)}
   */
  addPlayBackListener = (
    callback: (playbackMeta: PlayBackType) => void,
  ): void => {
    this._playerCallback = callback;
  };

  /**
   * remove listener for player.
   * @returns {void}
   */
  removePlayBackListener = (): void => {
    this._playerCallback = null;
  };

  /**
   * start recording with param.
   * @param {string} uri audio uri.
   * @returns {Promise<string>}
   */
  startRecorder = async (
    uri?: string,
    audioSets?: AudioSet,
    meteringEnabled?: boolean,
  ): Promise<string> => {
    if (!this._isRecording) {
      this._isRecording = true;

      try {
        return await RNAudioRecorderPlayer.startRecorder(
          uri ?? 'DEFAULT',
          audioSets,
          meteringEnabled ?? false,
        );
      } catch (error: any) {
        this._isRecording = false;
        throw error;
      }
    }

    return 'Already recording';
  };

  /**
   * Pause recording.
   * @returns {Promise<string>}
   */
  pauseRecorder = async (): Promise<string> => {
    if (!this._hasPausedRecord) {
      this._hasPausedRecord = true;

      return RNAudioRecorderPlayer.pauseRecorder();
    }

    return 'Already paused recording.';
  };

  /**
   * Resume recording.
   * @returns {Promise<string>}
   */
  resumeRecorder = async (): Promise<string> => {
    if (this._hasPausedRecord) {
      this._hasPausedRecord = false;

      return RNAudioRecorderPlayer.resumeRecorder();
    }

    return 'Currently recording.';
  };

  /**
   * stop recording.
   * @returns {Promise<string>}
   */
  stopRecorder = async (): Promise<string> => {
    if (this._isRecording) {
      this._isRecording = false;
      this._hasPausedRecord = false;
      this._isStopped = true;
      return RNAudioRecorderPlayer.stopRecorder();
    }

    return 'Already stopped';
  };

  /**
   * Resume playing.
   * @returns {Promise<string>}
   */
  resumePlayer = async (): Promise<string> => {
    if (!this._isPlaying) {
      return 'No audio playing';
    }

    if (this._hasPaused) {
      this._hasPaused = false;

      return RNAudioRecorderPlayer.resumePlayer();
    }

    return 'Already playing';
  };

  playerCallback = (event: PlayBackType): void => {
    if (this._playerCallback) {
      this._playerCallback(event);
    }

    if (event.isFinished) {
      this.stopPlayer();
    }
  };

  /**
   * Start playing with param.
   * @param {string} uri audio uri.
   * @param {Record<string, string>} httpHeaders Set of http headers.
   * @returns {Promise<string>}
   */
  startPlayer = async (
    uri?: string,
    httpHeaders?: Record<string, string>,
  ): Promise<string> => {
    if (!uri) {
      uri = 'DEFAULT';
    }

    if (!this._playerSubscription) {
      if (Platform.OS === 'android') {
        this._playerSubscription = DeviceEventEmitter.addListener(
          'rn-playback',
          this.playerCallback,
        );
      } else {
        const myModuleEvt = new NativeEventEmitter(RNAudioRecorderPlayer);

        this._playerSubscription = myModuleEvt.addListener(
          'rn-playback',
          this.playerCallback,
        );
      }
    }

    if (!this._isPlaying || this._hasPaused) {
      this._isPlaying = true;
      this._hasPaused = false;

      return RNAudioRecorderPlayer.startPlayer(uri, httpHeaders);
    }
  };

  /**
   * Stop playing.
   * @returns {Promise<string>}
   */
  stopPlayer = async (): Promise<string> => {
    if (this._isPlaying) {
      this._isPlaying = false;
      this._hasPaused = false;

      return RNAudioRecorderPlayer.stopPlayer();
    }

    return 'Already stopped playing';
  };

  /**
   * Pause playing.
   * @returns {Promise<string>}
   */
  pausePlayer = async (): Promise<string> => {
    if (!this._isPlaying) {
      return 'No audio playing';
    }

    if (!this._hasPaused) {
      this._hasPaused = true;

      return RNAudioRecorderPlayer.pausePlayer();
    }
  };

  /**
   * Seek to.
   * @param {number} time position seek to in millisecond.
   * @returns {Promise<string>}
   */
  seekToPlayer = async (time: number): Promise<string> => {
    return RNAudioRecorderPlayer.seekToPlayer(time);
  };

  /**
   * Set volume.
   * @param {number} setVolume set volume.
   * @returns {Promise<string>}
   */
  setVolume = async (volume: number): Promise<string> => {
    if (volume < 0 || volume > 1) {
      throw new Error('Value of volume should be between 0.0 to 1.0');
    }

    return RNAudioRecorderPlayer.setVolume(volume);
  };

  /**
   * Set playback speed.
   * @param {number} setPlaybackSpeed set playback speed.
   * @returns {Promise<string>}
   */
  setPlaybackSpeed = async (playbackSpeed: number): Promise<string> => {
    return RNAudioRecorderPlayer.setPlaybackSpeed(playbackSpeed);
  };

  /**
   * Set subscription duration. Default is 0.5.
   * @param {number} sec subscription callback duration in seconds.
   * @returns {Promise<string>}
   */
  setSubscriptionDuration = async (sec: number): Promise<string> => {
    return RNAudioRecorderPlayer.setSubscriptionDuration(sec);
  };

  getStatus = (): Status => {
    return {
      isPlaying: this._isPlaying,
      isRecording: this._isRecording,
      hasPaused: this._hasPaused,
      hasPausedRecord: this._hasPausedRecord,
      isStopped: this._isStopped,
    };
  };
}

export default AudioRecorderPlayer;
