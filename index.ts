import {
  DeviceEventEmitter,
  EmitterSubscription,
  NativeEventEmitter,
  NativeModules,
  Platform,
} from 'react-native';

const {RNAudioRecorderPlayer} = NativeModules;

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
  alac = 'alac',
  amr = 'amr',
  flac = 'flac',
  opus = 'opus',
}

type AVEncodingType =
  | AVEncodingOption.lpcm
  | AVEncodingOption.ima4
  | AVEncodingOption.aac
  | AVEncodingOption.MAC3
  | AVEncodingOption.MAC6
  | AVEncodingOption.ulaw
  | AVEncodingOption.alaw
  | AVEncodingOption.mp1
  | AVEncodingOption.mp2
  | AVEncodingOption.alac
  | AVEncodingOption.amr
  | AVEncodingOption.flac
  | AVEncodingOption.opus;

export enum AVEncoderAudioQualityIOSType {
  min = 0,
  low = 32,
  medium = 64,
  high = 96,
  max = 127,
}

export interface AudioSet {
  AVSampleRateKeyIOS?: number;
  AVFormatIDKeyIOS?: AVEncodingType;
  AVNumberOfChannelsKeyIOS?: number;
  AVEncoderAudioQualityKeyIOS?: AVEncoderAudioQualityIOSType;
  AudioSourceAndroid?: AudioSourceAndroidType;
  OutputFormatAndroid?: OutputFormatAndroidType;
  AudioEncoderAndroid?: AudioEncoderAndroidType;
  AudioEncodingBitRateAndroid?: number;
  AudioSamplingRateAndroid?: number;
}

const pad = (num: number): string => {
  return ('0' + num).slice(-2);
};

class AudioRecorderPlayer {
  private _isRecording: boolean;
  private _hasPausedRecording: boolean;
  private _isPlaying: boolean;
  private _hasPaused: boolean;
  private _recorderSubscription: EmitterSubscription;
  private _playerSubscription: EmitterSubscription;
  private _recordInterval: number;

  mmss = (secs: number): string => {
    let minutes = Math.floor(secs / 60);

    secs = secs % 60;
    minutes = minutes % 60;

    // minutes = ('0' + minutes).slice(-2);
    // secs = ('0' + secs).slice(-2);
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
   * set listerner from native module for recorder.
   * @returns {callBack(e: any)}
   */
  addRecordBackListener = (e): void => {
    if (Platform.OS === 'android')
      this._recorderSubscription = DeviceEventEmitter.addListener(
        'rn-recordback',
        e,
      );
    else {
      const myModuleEvt = new NativeEventEmitter(RNAudioRecorderPlayer);

      this._recorderSubscription = myModuleEvt.addListener('rn-recordback', e);
    }
  };

  /**
   * remove listener for recorder.
   * @returns {void}
   */
  removeRecordBackListener = (): void => {
    if (this._recorderSubscription) {
      this._recorderSubscription.remove();
      this._recorderSubscription = null;
    }
  };

  /**
   * set listener from native module for player.
   * @returns {callBack(e: Event)}
   */
  addPlayBackListener = (e): void => {
    if (Platform.OS === 'android')
      this._playerSubscription = DeviceEventEmitter.addListener(
        'rn-playback',
        e,
      );
    else {
      const myModuleEvt = new NativeEventEmitter(RNAudioRecorderPlayer);

      this._playerSubscription = myModuleEvt.addListener('rn-playback', e);
    }
  };

  /**
   * remove listener for player.
   * @returns {void}
   */
  removePlayBackListener = (): void => {
    if (this._playerSubscription) {
      this._playerSubscription.remove();
      this._playerSubscription = null;
    }
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
    if (!this._isRecording && !this._hasPausedRecording) {
      this._isRecording = true;
      return RNAudioRecorderPlayer.startRecorder(
        uri ?? 'DEFAULT',
        meteringEnabled ?? false,
        audioSets,
      );
    }

    return 'Already recording';
  };


  /**
   * pause recording.
   * @returns {Promise<boolean>}
   */
  pauseRecorder = async () : Promise<boolean> => {

    if(Platform.OS !== "ios"){
      return Promise.reject("Pause and resume only on ios")
    }

    if (this._isRecording) {
      this._isRecording = false;
      this._hasPausedRecording = true;

      return RNAudioRecorderPlayer.pauseRecorder();
    }
    return false;
  }

  /**
   * pause recording.
   * @returns {Promise<boolean>}
   */
  resumeRecorder = async () : Promise<boolean> => {

    if(Platform.OS !== "ios"){
      return Promise.reject("Pause and resume only on ios")
    }

    if (!this._isRecording && this._hasPausedRecording) {
      this._isRecording = true;
      this._hasPausedRecording = false;
      return RNAudioRecorderPlayer.resumeRecorder();
    }
    return false;
  }


  /**
   * stop recording.
   * @returns {Promise<string>}
   */
  stopRecorder = async (): Promise<string> => {
    if (this._isRecording) {
      this._isRecording = false;

      return RNAudioRecorderPlayer.stopRecorder();
    }

    return 'Already stopped';
  };

  /**
   * resume playing.
   * @returns {Promise<string>}
   */
  resumePlayer = async (): Promise<string> => {
    if (!this._isPlaying) return 'No audio playing';

    if (this._hasPaused) {
      this._hasPaused = false;

      return RNAudioRecorderPlayer.resumePlayer();
    }

    return 'Already playing';
  };

  /**
   * start playing with param.
   * @param {string} uri audio uri.
   * @param {Record<string, string>} httpHeaders Set of http headers.
   * @returns {Promise<string>}
   */
  startPlayer = async (
    uri?: string,
    httpHeaders?: Record<string, string>,
  ): Promise<string> => {
    if (!uri) uri = 'DEFAULT';

    if (!this._isPlaying || this._hasPaused) {
      this._isPlaying = true;
      this._hasPaused = false;

      if (Platform.OS === 'android')
        return RNAudioRecorderPlayer.startPlayer(uri, httpHeaders);

      return RNAudioRecorderPlayer.startPlayer(uri);
    }
  };

  /**
   * stop playing.
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
   * pause playing.
   * @returns {Promise<string>}
   */
  pausePlayer = async (): Promise<string> => {
    if (!this._isPlaying) return 'No audio playing';

    if (!this._hasPaused) {
      this._hasPaused = true;

      return RNAudioRecorderPlayer.pausePlayer();
    }
  };

  /**
   * seek to.
   * @param {number} time position seek to in second.
   * @returns {Promise<string>}
   */
  seekToPlayer = async (time: number): Promise<string> => {
    if (Platform.OS === 'ios') time = time / 1000;

    return RNAudioRecorderPlayer.seekToPlayer(time);
  };

  /**
   * set volume.
   * @param {number} setVolume set volume.
   * @returns {Promise<string>}
   */
  setVolume = async (volume: number): Promise<string> => {
    if (volume < 0 || volume > 1)
      throw new Error('Value of volume should be between 0.0 to 1.0');

    return RNAudioRecorderPlayer.setVolume(volume);
  };

  /**
   * set subscription duration.
   * @param {number} sec subscription callback duration in seconds.
   * @returns {Promise<string>}
   */
  setSubscriptionDuration = async (sec: number): Promise<string> => {
    return RNAudioRecorderPlayer.setSubscriptionDuration(sec);
  };
}

export default AudioRecorderPlayer;
