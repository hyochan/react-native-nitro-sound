import { useState } from 'react';
import type { EmitterSubscription } from 'react-native';
import {
  DeviceEventEmitter,
  NativeEventEmitter,
  NativeModules,
  Platform,
} from 'react-native';

const { RNAudioRecorderPlayer } = NativeModules;
import { AudioSet, PlayBackType, RecordBackType, Status, pad } from './types'
export function AudioRecorderPlayerFC() {
  const [isRecording, setIsRecording] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const [hasPaused, setHasPaused] = useState(false)
  const [hasPausedRecord, setHasPausedRecord] = useState(false)
  const [isStopped, setIsStopped] = useState(false)

  const [recorderSubscription, setRecorderSubscription] = useState<EmitterSubscription | null>(null)
  const [playerSubscription, setPlayerSubscription] = useState<EmitterSubscription | null>(null)
  const [_playerCallback, setPlayerCallback] = useState<((event: PlayBackType) => void) | null>(null)


  const mmss = (secs: number): string => {
    let minutes = Math.floor(secs / 60);

    secs = secs % 60;
    minutes = minutes % 60;

    return pad(minutes) + ':' + pad(secs);
  };

  const mmssss = (milisecs: number): string => {
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

  const addRecordBackListener = (
    callback: (recordingMeta: RecordBackType) => void,
  ): void => {
    if (Platform.OS === 'android') {
      setRecorderSubscription(DeviceEventEmitter.addListener(
        'rn-recordback',
        callback,
      ));
    } else {
      const myModuleEvt = new NativeEventEmitter(RNAudioRecorderPlayer);
      setRecorderSubscription(myModuleEvt.addListener(
        'rn-recordback',
        callback,
      ))
    }
  };

  /**
   * Remove listener for recorder.
   * @returns {void}
   */
  const removeRecordBackListener = (): void => {
    if (recorderSubscription) {
      recorderSubscription.remove();
      setRecorderSubscription(null);
    }
  };

  /**
   * Set listener from native module for player.
   * @returns {callBack((e: PlayBackType): void)}
   */
  const addPlayBackListener = (
    callback: (playbackMeta: PlayBackType) => void,
  ): void => {
    setPlayerCallback(callback);
  };

  /**
   * remove listener for player.
   * @returns {void}
   */
  const removePlayBackListener = (): void => {
    setPlayerCallback(null);
  };

  /**
   * start recording with param.
   * @param {string} uri audio uri.
   * @returns {Promise<string>}
   */
  const startRecorder = async (
    uri?: string,
    audioSets?: AudioSet,
    meteringEnabled?: boolean,
  ): Promise<string> => {
    if (!isRecording) {
      setIsRecording(true);

      try {
        return await RNAudioRecorderPlayer.startRecorder(
          uri ?? 'DEFAULT',
          audioSets,
          meteringEnabled ?? false,
        );
      } catch (error: any) {
        setIsRecording(false);
        throw error;
      }
    }

    return 'Already recording';
  };

  /**
   * Pause recording.
   * @returns {Promise<string>}
   */
  const pauseRecorder = async (): Promise<string> => {
    if (!hasPausedRecord) {
      setHasPausedRecord(true);

      return RNAudioRecorderPlayer.pauseRecorder();
    }

    return 'Already paused recording.';
  };

  /**
   * Resume recording.
   * @returns {Promise<string>}
   */
  const resumeRecorder = async (): Promise<string> => {
    if (hasPausedRecord) {
      setHasPausedRecord(false);

      return RNAudioRecorderPlayer.resumeRecorder();
    }

    return 'Currently recording.';
  };

  /**
   * stop recording.
   * @returns {Promise<string>}
   */
  const stopRecorder = async (): Promise<string> => {
    if (isRecording) {
      setIsRecording(false);
      setHasPausedRecord(false);
      setIsStopped(true)
      return RNAudioRecorderPlayer.stopRecorder();
    }

    return 'Already stopped';
  };

  /**
   * Resume playing.
   * @returns {Promise<string>}
   */
  const resumePlayer = async (): Promise<string> => {
    if (!isPlaying) {
      return 'No audio playing';
    }

    if (hasPaused) {
      setHasPaused(false);

      return RNAudioRecorderPlayer.resumePlayer();
    }

    return 'Already playing';
  };

  const playerCallback = (event: PlayBackType): void => {
    if (_playerCallback) {
      _playerCallback(event);
    }

    if (event.isFinished) {
      stopPlayer();
    }
  };

  /**
   * Start playing with param.
   * @param {string} uri audio uri.
   * @param {Record<string, string>} httpHeaders Set of http headers.
   * @returns {Promise<string>}
   */
  const startPlayer = async (
    uri?: string,
    httpHeaders?: Record<string, string>,
  ): Promise<string> => {
    if (!uri) {
      uri = 'DEFAULT';
    }

    if (!playerSubscription) {
      if (Platform.OS === 'android') {
        setPlayerSubscription(DeviceEventEmitter.addListener(
          'rn-playback',
          playerCallback,
        ))
      } else {
        const myModuleEvt = new NativeEventEmitter(RNAudioRecorderPlayer);

        setPlayerSubscription(myModuleEvt.addListener(
          'rn-playback',
          playerCallback,
        ));
      }
    }

    if (!isPlaying || hasPaused) {
      setIsPlaying(true);
      setHasPaused(false);

      return RNAudioRecorderPlayer.startPlayer(uri, httpHeaders);
    }
    return `Playing out of sync: playing: ${isPlaying}, paused: ${hasPaused}, subscription: ${playerSubscription}`
  };

  /**
   * Stop playing.
   * @returns {Promise<string>}
   */
  const stopPlayer = async (): Promise<string> => {
    if (isPlaying) {
      setIsPlaying(false);
      setHasPaused(false);

      return RNAudioRecorderPlayer.stopPlayer();
    }

    return 'Already stopped playing';
  };

  /**
   * Pause playing.
   * @returns {Promise<string>}
   */
  const pausePlayer = async (): Promise<string> => {
    if (!isPlaying) {
      return 'No audio playing';
    }

    if (!hasPaused) {
      setHasPaused(true);

      return RNAudioRecorderPlayer.pausePlayer();
    }
    return `Pausing out of sync: playing: ${isPlaying}, paused: ${hasPaused}`
  };

  /**
   * Seek to.
   * @param {number} time position seek to in millisecond.
   * @returns {Promise<string>}
   */
  const seekToPlayer = async (time: number): Promise<string> => {
    return RNAudioRecorderPlayer.seekToPlayer(time);
  };

  /**
   * Set volume.
   * @param {number} setVolume set volume.
   * @returns {Promise<string>}
   */
  const setVolume = async (volume: number): Promise<string> => {
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
  const setPlaybackSpeed = async (playbackSpeed: number): Promise<string> => {
    return RNAudioRecorderPlayer.setPlaybackSpeed(playbackSpeed);
  };

  /**
   * Set subscription duration. Default is 0.5.
   * @param {number} sec subscription callback duration in seconds.
   * @returns {Promise<string>}
   */
  const setSubscriptionDuration = async (sec: number): Promise<string> => {
    return RNAudioRecorderPlayer.setSubscriptionDuration(sec);
  };

  const getStatus = (): Status => {
    return {
      isPlaying,
      isRecording,
      hasPaused,
      hasPausedRecord,
      isStopped
    }
  }
  return {
    getStatus,
    setSubscriptionDuration,
    setPlaybackSpeed,
    setVolume,
    seekToPlayer,
    pausePlayer,
    stopPlayer,
    mmssss,
    mmss,
    addRecordBackListener,
    startPlayer,
    playerCallback,
    stopRecorder,
    resumePlayer,
    resumeRecorder,
    pauseRecorder,
    removePlayBackListener,
    startRecorder,
    addPlayBackListener,
    removeRecordBackListener
  }
}