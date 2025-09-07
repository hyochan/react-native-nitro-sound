import type {
  Sound as SoundType,
  AudioSet,
  RecordBackType,
  PlayBackType,
  PlaybackEndType,
} from './specs/Sound.nitro';

export * from './specs/Sound.nitro';

class SoundWebImpl implements SoundType {
  private mediaRecorder: MediaRecorder | null = null;
  private audioContext: AudioContext | null = null;
  private audio: HTMLAudioElement | null = null;
  private recordedChunks: Blob[] = [];
  private recordingStartTime: number = 0;
  private actualRecordedDuration: number = 0;
  private recordBackListener: ((recordingMeta: RecordBackType) => void) | null =
    null;
  private playBackListener: ((playbackMeta: PlayBackType) => void) | null =
    null;
  private playbackEndListener:
    | ((playbackEndMeta: PlaybackEndType) => void)
    | null = null;
  private recordingInterval: NodeJS.Timeout | null = null;
  private playbackInterval: NodeJS.Timeout | null = null;
  private subscriptionDuration: number = 10; // Default 10ms for faster updates
  private currentVolume: number = 1.0;
  private recordingUrl: string | null = null;
  private mediaStream: MediaStream | null = null;
  private lastSourceUrl: string | null = null;

  // Recording methods
  async startRecorder(
    _uri?: string,
    audioSets?: AudioSet,
    meteringEnabled?: boolean
  ): Promise<string> {
    try {
      // Get user media
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: audioSets?.AudioChannels || 1,
          sampleRate: audioSets?.AudioSamplingRate || 44100,
          echoCancellation: true,
          noiseSuppression: true,
        },
      });

      // Setup audio context for metering
      if (meteringEnabled && !this.audioContext) {
        this.audioContext = new AudioContext();
      }

      // Create MediaRecorder
      const options: MediaRecorderOptions = {
        mimeType: this.getMimeType(audioSets),
        audioBitsPerSecond: audioSets?.AudioEncodingBitRate || 128000,
      };

      this.mediaRecorder = new MediaRecorder(stream, options);
      this.recordedChunks = [];

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };

      // Store stream reference for cleanup
      this.mediaStream = stream;

      // Start recording with timeslice to get more accurate chunks
      this.mediaRecorder.start(100); // Capture data every 100ms
      this.recordingStartTime = Date.now();

      // Start progress updates
      this.startRecordingProgress(meteringEnabled || false);

      // Return a placeholder until recording is stopped
      return 'recording_in_progress';
    } catch (error) {
      console.error('Failed to start recording:', error);
      throw new Error(`Failed to start recording: ${error}`);
    }
  }

  async pauseRecorder(): Promise<string> {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.pause();
      this.stopRecordingProgress();
      return 'paused';
    }
    throw new Error('No active recording to pause');
  }

  async resumeRecorder(): Promise<string> {
    if (this.mediaRecorder && this.mediaRecorder.state === 'paused') {
      this.mediaRecorder.resume();
      this.startRecordingProgress(false);
      return 'resumed';
    }
    throw new Error('No paused recording to resume');
  }

  async stopRecorder(): Promise<string> {
    if (this.mediaRecorder) {
      return new Promise((resolve) => {
        const mimeType = this.mediaRecorder!.mimeType || 'audio/webm';

        // Calculate actual duration before stopping
        this.actualRecordedDuration = Date.now() - this.recordingStartTime;

        this.mediaRecorder!.onstop = () => {
          const blob = new Blob(this.recordedChunks, {
            type: mimeType,
          });
          const url = URL.createObjectURL(blob);
          this.recordingUrl = url;

          // Clean up the stream
          if (this.mediaStream) {
            this.mediaStream.getTracks().forEach((track) => track.stop());
            this.mediaStream = null;
          }

          // Clean up media recorder
          this.mediaRecorder = null;

          resolve(url);
        };

        this.mediaRecorder!.stop();
        this.stopRecordingProgress();
      });
    }
    throw new Error('No active recording to stop');
  }

  // Playback methods
  async startPlayer(
    uri?: string,
    httpHeaders?: Record<string, string>
  ): Promise<string> {
    try {
      // Determine requested URL to play (remote or last recording)
      let requestedUrl: string | null = null;
      let createdObjectUrl: string | null = null;

      if (uri) {
        if (httpHeaders && Object.keys(httpHeaders).length > 0) {
          const response = await fetch(uri, { headers: httpHeaders });
          const blob = await response.blob();
          requestedUrl = URL.createObjectURL(blob);
          createdObjectUrl = requestedUrl;
        } else {
          requestedUrl = uri;
        }
      } else if (this.recordingUrl) {
        requestedUrl = this.recordingUrl;
      }

      // If we already have an audio element and it's paused on the same source, just resume
      if (this.audio && this.audio.paused) {
        const currentSrc = this.audio.currentSrc || this.audio.src;
        if (!requestedUrl || currentSrc === requestedUrl) {
          await this.audio.play();
          this.startPlaybackProgress();
          return currentSrc || requestedUrl || '';
        }
      }

      // Create or replace audio element for a (new or same) source
      this.audio = new Audio();
      this.audio.volume = this.currentVolume;
      if (!requestedUrl) throw new Error('No audio URI provided');
      this.audio.src = requestedUrl;
      this.lastSourceUrl = requestedUrl;

      // Add ended event listener
      this.audio.onended = () => {
        this.stopPlaybackProgress();

        const finalDuration =
          this.actualRecordedDuration > 0
            ? this.actualRecordedDuration
            : this.audio!.duration * 1000;

        if (this.playBackListener) {
          // Send final update with exact duration
          this.playBackListener({
            isMuted: this.audio!.muted,
            duration: finalDuration,
            currentPosition: finalDuration,
          });
        }

        if (this.playbackEndListener) {
          // Send playback end event
          this.playbackEndListener({
            duration: finalDuration,
            currentPosition: finalDuration,
          });
        }
      };

      await this.audio.play();
      this.startPlaybackProgress();

      return requestedUrl;
    } catch (error) {
      console.error('Failed to start playback:', error);
      throw new Error(`Failed to start playback: ${error}`);
    }
  }

  async stopPlayer(): Promise<string> {
    if (this.audio) {
      this.audio.pause();
      this.audio.currentTime = 0;
      this.stopPlaybackProgress();
      this.audio = null;
      return 'stopped';
    }
    throw new Error('No active playback to stop');
  }

  async pausePlayer(): Promise<string> {
    if (this.audio && !this.audio.paused) {
      this.audio.pause();
      this.stopPlaybackProgress();
      return 'paused';
    }
    throw new Error('No active playback to pause');
  }

  async resumePlayer(): Promise<string> {
    if (this.audio && this.audio.paused) {
      await this.audio.play();
      this.startPlaybackProgress();
      return 'resumed';
    }
    throw new Error('No paused playback to resume');
  }

  async seekToPlayer(time: number): Promise<string> {
    if (this.audio) {
      this.audio.currentTime = time / 1000; // Convert ms to seconds
      return `${time}`;
    }
    throw new Error('No active playback to seek');
  }

  async setVolume(volume: number): Promise<string> {
    this.currentVolume = Math.max(0, Math.min(1, volume));
    if (this.audio) {
      this.audio.volume = this.currentVolume;
    }
    return `${this.currentVolume}`;
  }

  async setPlaybackSpeed(playbackSpeed: number): Promise<string> {
    if (this.audio) {
      this.audio.playbackRate = playbackSpeed;
      return `${playbackSpeed}`;
    }
    throw new Error('No active playback to set speed');
  }

  // Subscription
  setSubscriptionDuration(sec: number): void {
    // For web, use milliseconds directly for faster updates
    this.subscriptionDuration = Math.max(10, sec * 1000); // Convert to ms, minimum 10ms
  }

  // Listeners
  addRecordBackListener(
    callback: (recordingMeta: RecordBackType) => void
  ): void {
    this.recordBackListener = callback;
  }

  removeRecordBackListener(): void {
    this.recordBackListener = null;
  }

  addPlayBackListener(callback: (playbackMeta: PlayBackType) => void): void {
    this.playBackListener = callback;
  }

  removePlayBackListener(): void {
    this.playBackListener = null;
  }

  addPlaybackEndListener(
    callback: (playbackEndMeta: PlaybackEndType) => void
  ): void {
    this.playbackEndListener = callback;
  }

  removePlaybackEndListener(): void {
    this.playbackEndListener = null;
  }

  // Utility methods
  mmss(secs: number): string {
    const minutes = Math.floor(secs / 60);
    const seconds = Math.floor(secs % 60);
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  mmssss(milisecs: number): string {
    const totalSeconds = Math.floor(milisecs / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const milliseconds = Math.floor((milisecs % 1000) / 10);
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}:${milliseconds.toString().padStart(2, '0')}`;
  }

  // Private helper methods
  private getMimeType(_audioSets?: AudioSet): string {
    // Try to use webm/opus for best browser support
    if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
      return 'audio/webm;codecs=opus';
    }
    if (MediaRecorder.isTypeSupported('audio/webm')) {
      return 'audio/webm';
    }
    if (MediaRecorder.isTypeSupported('audio/mp4')) {
      return 'audio/mp4';
    }
    return 'audio/wav';
  }

  private startRecordingProgress(meteringEnabled: boolean): void {
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
    }

    const startTime = performance.now();

    this.recordingInterval = setInterval(() => {
      if (
        this.recordBackListener &&
        this.mediaRecorder?.state === 'recording'
      ) {
        const currentPosition = performance.now() - startTime;

        this.recordBackListener({
          isRecording: true,
          currentPosition,
          currentMetering: meteringEnabled
            ? this.getCurrentMetering()
            : undefined,
          // Keep consistent with native (ms)
          recordSecs: currentPosition,
        });
      }
    }, this.subscriptionDuration);
  }

  private stopRecordingProgress(): void {
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
      this.recordingInterval = null;
    }
  }

  private startPlaybackProgress(): void {
    if (this.playbackInterval) {
      clearInterval(this.playbackInterval);
    }

    this.playbackInterval = setInterval(() => {
      if (this.playBackListener && this.audio && !this.audio.paused) {
        // Use actual recorded duration if available and audio duration is not accurate
        const duration =
          this.actualRecordedDuration > 0
            ? this.actualRecordedDuration
            : this.audio.duration * 1000;

        const currentPosition = this.audio.currentTime * 1000;

        // Ensure we don't exceed duration
        const safePosition = Math.min(currentPosition, duration);

        this.playBackListener({
          isMuted: this.audio.muted,
          duration: duration,
          currentPosition: safePosition,
        });

        // Check if playback has ended
        if (this.audio.ended || currentPosition >= duration) {
          this.stopPlaybackProgress();
          if (this.playBackListener) {
            // Send final update with 100% progress
            this.playBackListener({
              isMuted: this.audio.muted,
              duration: duration,
              currentPosition: duration,
            });
          }
        }
      }
    }, this.subscriptionDuration);
  }

  private stopPlaybackProgress(): void {
    if (this.playbackInterval) {
      clearInterval(this.playbackInterval);
      this.playbackInterval = null;
    }
  }

  private getCurrentMetering(): number {
    // Simplified metering - in a real implementation, you'd analyze the audio stream
    return Math.random() * 40 - 40; // Random value between -40 and 0 dB
  }

  // Required by HybridObject interface but not used in web
  get name(): string {
    return 'Sound';
  }

  equals(other: SoundType): boolean {
    return other === this;
  }

  get hashCode(): number {
    return 0;
  }

  toString(): string {
    return 'Sound (Web)';
  }

  dispose(): void {
    this.stopRecorder().catch(() => {});
    this.stopPlayer().catch(() => {});
    this.removeRecordBackListener();
    this.removePlayBackListener();
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
  }
}
// Factory for web: produce multiple independent instances
export function createSound(): SoundType {
  return new SoundWebImpl();
}

// Backward-compatible singleton (legacy API)
let _singleton: SoundType | null = null;
const getSingleton = (): SoundType => {
  if (!_singleton) _singleton = createSound();
  return _singleton;
};

const Sound: SoundType = new Proxy({} as SoundType, {
  get(_target, prop: keyof SoundType) {
    const inst = getSingleton();
    const value = (inst as any)[prop];
    if (typeof value === 'function') return value.bind(inst);
    return value;
  },
}) as SoundType;

export default Sound;
export { Sound };
export { useSound } from './useSound';
