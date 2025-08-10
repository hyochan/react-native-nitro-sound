import type {
  AudioSet,
  RecordBackType,
  PlayBackType,
} from './NativeAudioRecorderPlayer.web';

export type { AudioSet, RecordBackType, PlayBackType };
export {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AVEncoderAudioQualityIOSType,
} from './NativeAudioRecorderPlayer.web';

export interface PlaybackEndType {
  finished: boolean;
  duration?: number;
  currentPosition?: number;
}

class AudioRecorderPlayerImpl {
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private audioPlayer: HTMLAudioElement | null = null;
  private recordingStartTime: number = 0;
  private recordingTimer: NodeJS.Timeout | null = null;
  private playbackTimer: NodeJS.Timeout | null = null;
  private recordCallback: ((data: RecordBackType) => void) | null = null;
  private playbackCallback: ((data: PlayBackType) => void) | null = null;
  private playbackEndCallback: ((data: PlaybackEndType) => void) | null = null;
  private subscriptionDuration: number = 60; // milliseconds
  private recordedBlob: Blob | null = null;
  private recordedUrl: string | null = null;

  // Recording methods
  async startRecorder(
    uri?: string,
    _audioSets?: AudioSet,
    _meteringEnabled?: boolean
  ): Promise<string> {
    try {
      // Request microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

      // Create MediaRecorder
      const mimeType = MediaRecorder.isTypeSupported('audio/webm')
        ? 'audio/webm'
        : 'audio/ogg';
      this.mediaRecorder = new MediaRecorder(stream, { mimeType });
      this.audioChunks = [];

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        // Create blob from chunks
        this.recordedBlob = new Blob(this.audioChunks, { type: mimeType });
        this.recordedUrl = URL.createObjectURL(this.recordedBlob);

        // Stop all tracks
        stream.getTracks().forEach((track) => track.stop());
      };

      // Start recording
      this.mediaRecorder.start();
      this.recordingStartTime = Date.now();

      // Start timer for recording progress
      this.startRecordingTimer();

      console.log('Web recording started');
      return uri || 'web-recording';
    } catch (error) {
      console.error('Failed to start recording:', error);
      throw error;
    }
  }

  async pauseRecorder(): Promise<string> {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.pause();
      this.stopRecordingTimer();
      console.log('Web recording paused');
      return 'Recording paused';
    }
    return 'Not recording';
  }

  async resumeRecorder(): Promise<string> {
    if (this.mediaRecorder && this.mediaRecorder.state === 'paused') {
      this.mediaRecorder.resume();
      this.startRecordingTimer();
      console.log('Web recording resumed');
      return 'Recording resumed';
    }
    return 'Not paused';
  }

  async stopRecorder(): Promise<string> {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      return new Promise((resolve) => {
        if (this.mediaRecorder) {
          this.mediaRecorder.onstop = () => {
            // Create blob from chunks
            const mimeType = this.mediaRecorder?.mimeType || 'audio/webm';
            this.recordedBlob = new Blob(this.audioChunks, { type: mimeType });
            this.recordedUrl = URL.createObjectURL(this.recordedBlob);

            this.stopRecordingTimer();
            console.log('Web recording stopped');
            resolve(this.recordedUrl || 'web-recording-stopped');
          };

          this.mediaRecorder.stop();
        }
      });
    }
    return 'Not recording';
  }

  // Playback methods
  async startPlayer(
    uri?: string,
    _httpHeaders?: Record<string, string>
  ): Promise<string> {
    try {
      // Use recorded audio or provided URI
      const audioUrl = uri || this.recordedUrl;

      if (!audioUrl) {
        throw new Error('No audio URL provided');
      }

      // Create audio element
      this.audioPlayer = new Audio(audioUrl);

      // Set up event listeners
      this.audioPlayer.onended = () => {
        this.stopPlaybackTimer();
        if (this.playbackEndCallback) {
          this.playbackEndCallback({
            finished: true,
            duration: (this.audioPlayer?.duration || 0) * 1000,
            currentPosition: (this.audioPlayer?.duration || 0) * 1000,
          });
        }
      };

      // Start playback
      await this.audioPlayer.play();

      // Start timer for playback progress
      this.startPlaybackTimer();

      console.log('Web playback started');
      return audioUrl;
    } catch (error) {
      console.error('Failed to start playback:', error);
      throw error;
    }
  }

  async stopPlayer(): Promise<string> {
    if (this.audioPlayer) {
      this.audioPlayer.pause();
      this.audioPlayer.currentTime = 0;
      this.stopPlaybackTimer();
      this.audioPlayer = null;
      console.log('Web playback stopped');
      return 'Playback stopped';
    }
    return 'Not playing';
  }

  async pausePlayer(): Promise<string> {
    if (this.audioPlayer && !this.audioPlayer.paused) {
      this.audioPlayer.pause();
      this.stopPlaybackTimer();
      console.log('Web playback paused');
      return 'Playback paused';
    }
    return 'Not playing';
  }

  async resumePlayer(): Promise<string> {
    if (this.audioPlayer && this.audioPlayer.paused) {
      await this.audioPlayer.play();
      this.startPlaybackTimer();
      console.log('Web playback resumed');
      return 'Playback resumed';
    }
    return 'Not paused';
  }

  async seekToPlayer(time: number): Promise<string> {
    if (this.audioPlayer) {
      this.audioPlayer.currentTime = time / 1000; // Convert ms to seconds
      return 'Seek completed';
    }
    return 'Not playing';
  }

  async setVolume(volume: number): Promise<string> {
    if (this.audioPlayer) {
      this.audioPlayer.volume = Math.max(0, Math.min(1, volume));
      return 'Volume set';
    }
    return 'Not playing';
  }

  async setPlaybackSpeed(playbackSpeed: number): Promise<string> {
    if (this.audioPlayer) {
      this.audioPlayer.playbackRate = playbackSpeed;
      return 'Playback speed set';
    }
    return 'Not playing';
  }

  // Subscription
  setSubscriptionDuration(sec: number): void {
    this.subscriptionDuration = sec * 1000; // Convert to milliseconds
  }

  // Timer methods
  private startRecordingTimer(): void {
    this.stopRecordingTimer();

    this.recordingTimer = setInterval(() => {
      if (this.recordCallback && this.mediaRecorder?.state === 'recording') {
        const currentPosition = Date.now() - this.recordingStartTime;
        this.recordCallback({
          isRecording: true,
          currentPosition,
          currentMetering: 0, // Web doesn't provide metering
        });
      }
    }, this.subscriptionDuration);
  }

  private stopRecordingTimer(): void {
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
  }

  private startPlaybackTimer(): void {
    this.stopPlaybackTimer();

    this.playbackTimer = setInterval(() => {
      if (
        this.playbackCallback &&
        this.audioPlayer &&
        !this.audioPlayer.paused
      ) {
        this.playbackCallback({
          isMuted: this.audioPlayer.muted,
          currentPosition: this.audioPlayer.currentTime * 1000,
          duration: this.audioPlayer.duration * 1000,
        });
      }
    }, this.subscriptionDuration);
  }

  private stopPlaybackTimer(): void {
    if (this.playbackTimer) {
      clearInterval(this.playbackTimer);
      this.playbackTimer = null;
    }
  }

  // Listeners
  addRecordBackListener(
    callback: (recordingMeta: RecordBackType) => void
  ): void {
    this.recordCallback = callback;
  }

  removeRecordBackListener(): void {
    this.recordCallback = null;
  }

  addPlayBackListener(callback: (playbackMeta: PlayBackType) => void): void {
    this.playbackCallback = callback;
  }

  removePlayBackListener(): void {
    this.playbackCallback = null;
  }

  addPlaybackEndListener(
    callback: (playbackEndMeta: PlaybackEndType) => void
  ): void {
    this.playbackEndCallback = callback;
  }

  removePlaybackEndListener(): void {
    this.playbackEndCallback = null;
  }

  // Utility methods
  mmss(secs: number): string {
    const seconds = Math.floor(secs);
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
  }

  mmssss(milisecs: number): string {
    const totalSeconds = Math.floor(milisecs / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const milliseconds = Math.floor((milisecs % 1000) / 10);
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}:${milliseconds.toString().padStart(2, '0')}`;
  }
}

// Create singleton instance
const AudioRecorderPlayer = new AudioRecorderPlayerImpl();

export default AudioRecorderPlayer;
