import type { TurboModule } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  addListener(eventType: string): void;
  removeListeners(count: number): void;

  startRecorder(
    uri: string,
    meteringEnabled: boolean,
    audioSets?: {
      AVSampleRateKeyIOS?: number;
      AVFormatIDKeyIOS?: 'lpcm' | 'ima4' | 'aac' | 'MAC3' | 'MAC6' | 'ulaw' | 'alaw' | 'mp1' | 'mp2' | 'mp4' | 'alac' | 'amr' | 'flac' | 'opus' | 'wav';
      AVModeIOS?: 'gamechat' | 'measurement' | 'movieplayback' | 'spokenaudio' | 'videochat' | 'videorecording' | 'voicechat' | 'voiceprompt';
      AVNumberOfChannelsKeyIOS?: number;
      AVEncoderAudioQualityKeyIOS?: 0 | 32 | 64 | 96 | 127;
      AudioSourceAndroid?: 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 1998 | 10;
      AVLinearPCMBitDepthKeyIOS?: 8 | 16 | 24 | 32;
      AVLinearPCMIsBigEndianKeyIOS?: boolean;
      AVLinearPCMIsFloatKeyIOS?: boolean;
      AVLinearPCMIsNonInterleavedIOS?: boolean;
      AVEncoderBitRateKeyIOS?: number;
      OutputFormatAndroid?: 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;
      AudioEncoderAndroid?: 0 | 1 | 2 | 3 | 4 | 5 | 6;
      AudioEncodingBitRateAndroid?: number;
      AudioSamplingRateAndroid?: number;
      AudioChannelsAndroid?: number;
    },
  ): Promise<string>;

  resumeRecorder(): Promise<string>;
  pauseRecorder(): Promise<string>;
  stopRecorder(): Promise<string>;

  setVolume(volume: Double): Promise<string>;

  startPlayer(
    uri: string,
    httpHeaders?: { [key: string]: unknown },
  ): Promise<string>;

  resumePlayer(): Promise<string>;
  pausePlayer(): Promise<string>;
  seekToPlayer(time: Double): Promise<string>;
  stopPlayer(): Promise<string>;

  setSubscriptionDuration(sec: Double): Promise<string>;
}

export default TurboModuleRegistry.get<Spec>(
  'RNAudioRecorderPlayer',
) as Spec | null;
