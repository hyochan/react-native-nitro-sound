import { NitroModules } from 'react-native-nitro-modules';
import type {
  Sound as SoundType,
  AudioSet,
  RecordBackType,
  PlayBackType,
  PlaybackEndType,
} from './specs/Sound.nitro';

export * from './specs/Sound.nitro';

class SoundImpl {
  private hybridObject: SoundType | null = null;

  private getHybridObject(): SoundType {
    if (!this.hybridObject) {
      try {
        console.log('🔧 Creating Sound HybridObject...');
        this.hybridObject = NitroModules.createHybridObject<SoundType>('Sound');
        console.log(
          '🔧 HybridObject created successfully:',
          !!this.hybridObject
        );
      } catch (error) {
        console.error('🔧 Failed to create HybridObject:', error);
        throw new Error(`Failed to create Sound HybridObject: ${error}`);
      }
    }
    return this.hybridObject;
  }

  // Recording methods
  async startRecorder(
    uri?: string,
    audioSets?: AudioSet,
    meteringEnabled?: boolean
  ): Promise<string> {
    try {
      console.log('🔧 Getting HybridObject for startRecorder...');
      const hybridObject = this.getHybridObject();
      console.log('🔧 HybridObject obtained, calling startRecorder...');
      console.log('🔧 Parameters:', { uri, audioSets, meteringEnabled });

      const result = await hybridObject.startRecorder(
        uri,
        audioSets,
        meteringEnabled
      );
      console.log('🔧 startRecorder completed with result:', result);
      return result;
    } catch (error) {
      console.error('🔧 startRecorder failed:', error);
      throw error;
    }
  }

  async pauseRecorder(): Promise<string> {
    return this.getHybridObject().pauseRecorder();
  }

  async resumeRecorder(): Promise<string> {
    return this.getHybridObject().resumeRecorder();
  }

  async stopRecorder(): Promise<string> {
    return this.getHybridObject().stopRecorder();
  }

  // Playback methods
  async startPlayer(
    uri?: string,
    httpHeaders?: Record<string, string>
  ): Promise<string> {
    return this.getHybridObject().startPlayer(uri, httpHeaders);
  }

  async stopPlayer(): Promise<string> {
    return this.getHybridObject().stopPlayer();
  }

  async pausePlayer(): Promise<string> {
    return this.getHybridObject().pausePlayer();
  }

  async resumePlayer(): Promise<string> {
    return this.getHybridObject().resumePlayer();
  }

  async seekToPlayer(time: number): Promise<string> {
    return this.getHybridObject().seekToPlayer(time);
  }

  async setVolume(volume: number): Promise<string> {
    return this.getHybridObject().setVolume(volume);
  }

  async setPlaybackSpeed(playbackSpeed: number): Promise<string> {
    return this.getHybridObject().setPlaybackSpeed(playbackSpeed);
  }

  // Subscription
  setSubscriptionDuration(sec: number): void {
    this.getHybridObject().setSubscriptionDuration(sec);
  }

  // Listeners
  addRecordBackListener(
    callback: (recordingMeta: RecordBackType) => void
  ): void {
    this.getHybridObject().addRecordBackListener(callback);
  }

  removeRecordBackListener(): void {
    this.getHybridObject().removeRecordBackListener();
  }

  addPlayBackListener(callback: (playbackMeta: PlayBackType) => void): void {
    this.getHybridObject().addPlayBackListener(callback);
  }

  removePlayBackListener(): void {
    this.getHybridObject().removePlayBackListener();
  }

  addPlaybackEndListener(
    callback: (playbackEndMeta: PlaybackEndType) => void
  ): void {
    this.getHybridObject().addPlaybackEndListener(callback);
  }

  removePlaybackEndListener(): void {
    this.getHybridObject().removePlaybackEndListener();
  }

  // Utility methods
  mmss(secs: number): string {
    return this.getHybridObject().mmss(secs);
  }

  mmssss(milisecs: number): string {
    return this.getHybridObject().mmssss(milisecs);
  }
}

// Create singleton instance
const Sound = new SoundImpl();

export default Sound;
