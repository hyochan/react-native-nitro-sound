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

interface AVEncodingOption {
  lpcm: 'lpcm';
  ima4: 'ima4';
  aac: 'aac';
  MAC3: 'MAC3';
  MAC6: 'MAC6';
  ulaw: 'ulaw';
  alaw: 'alaw';
  mp1: 'mp1';
  mp2: 'mp2';
  alac: 'alac';
  amr: 'amr';
  flac: 'flac';
  opus: 'opus';
}

export enum AVEncoderAudioQualityIOSType {
  min = 0,
  low = 32,
  medium = 64,
  high = 96,
  max = 127,
}

interface AudioSet {
  AVSampleRateKeyIOS?: number;
  AVFormatIDKeyIOS?: AVEncodingType;
  AVNumberOfChannelsKeyIOS?: number;
  AVEncoderAudioQualityKeyIOS?: AVEncoderAudioQualityIOSType;
  AudioSourceAndroid?: AudioSourceAndroidType;
  OutputFormatAndroid?: OutputFormatAndroidType;
  AudioEncoderAndroid?: AudioEncoderAndroidType;
}

export default class AudioRecorderPlayer {
  private _isRecording: boolean;
  private _isPlaying: boolean;
  private _subscription: any;

  /**
   * Convert seconds into minute:second string format.
   * @param {string} seconds
   * @returns {string} 00:00
   */
  public mmss(secs: number): string;

  /**
   * Convert seconds into minute:second:millis string format.
   * @param {string} miliseconds
   * @returns {string} 00:00:00
   */
  public mmssss(milisecs: number): string;

  /**
   * Add playback listener.
   * @param {Event} playback current_position, duration
   * @returns {void}
   */
  public addRecordBackListener(fn: Function): void;

  /**
   * Remove playback listener.
   * @returns {void}
   */
  public removeRecordBackListener(): void;

  /**
   * Add playback listener.
   * @param {Event} playback current_position, duration
   * @returns {void}
   */
  public addPlayBackListener(fn: Function): void;

  /**
   * Remove playback listener.
   * @returns {void}
   */
  public removePlayBackListener(): void;

  /**
   * Set callback duration. Default is 0.01 which will be heavy apps doing many things concurrently.
   */
  public setSubscriptionDuration(): Promise<string>;

  /**
   * Start recording.
   * @param {uri} audioPathUri no param will save audio in default location.
   * @param {AudioSet} audioSet additional parameters to give values to recorder to change sound quality.
   * @returns {Promise<string>} audioFileURI
   */
  public startRecorder(uri?: string, audioSets?: AudioSet): Promise<string>;

  /**
   * Stop recording.
   * @returns {Promise<string>}
   */
  public stopRecorder(): Promise<string>;

  /**
   * Start playing.
   * @param {uri} audioPathUri no param will save audio in default location
   * @returns {Promise<string>} audioFileURI
   */
  public startPlayer(uri?: string): Promise<string>;

  /**
   * Stop playing.
   * @returns {Promise<string>}
   */
  public stopPlayer(): Promise<string>;

  /**
   * Pause playing.
   * @returns {Promise<string>}
   */
  public pausePlayer(): Promise<string>;

  /**
   * Resume playing.
   * @returns {Promise<string>}
   */
  public resumePlayer(): Promise<string>;

  /**
   * Seek to.
   * @param {string} time position seek to in second.
   * @returns {Promise<string>}
   */
  public seekToPlayer(time: number): Promise<string>;

  /**
   * Set volume.
   * @param {string} volume volume range 0.0 to 1.0.
   * @returns {Promise<string>}
   */
  public setVolume(volume: number): Promise<string>;

  /**
   * setSubscriptionDuration.
   * @param {number} sec subscription callback duration in seconds.
   * @returns {Promise<string>}
   */
  public setSubscriptionDuration(time: number): Promise<string>;
}
