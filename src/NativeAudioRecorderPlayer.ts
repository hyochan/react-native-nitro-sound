import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';
import type {Double} from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  startRecorder(
    uri: string,
    meteringEnabled: boolean,
    audioSets?: Object,
  ): Promise<string>;
  resumeRecorder(): Promise<string>;
  pauseRecorder(): Promise<string>;
  stopRecorder(): Promise<string>;
  setVolume(volume: Double): Promise<string>;
  startPlayer(uri: string, httpHeaders?: Object): Promise<string>;
  resumePlayer(): Promise<string>;
  pausePlayer(): Promise<string>;
  seekToPlayer(time: Double): Promise<string>;
  stopPlayer(): Promise<string>;
  setSubscriptionDuration(sec: Double): Promise<string>;
}

export default TurboModuleRegistry.get<Spec>(
  'RNAudioRecorderPlayer',
) as Spec | null;
