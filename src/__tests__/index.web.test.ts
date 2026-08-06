jest.mock('react-native-nitro-modules', () => ({
  NitroModules: {
    createHybridObject: jest.fn(),
  },
}));

import { createSound } from '../index.web';

type RecorderEvent = { data: Blob };

class MockMediaRecorder {
  static isTypeSupported = jest.fn(() => true);

  readonly mimeType: string;
  state: RecordingState = 'inactive';
  ondataavailable: ((event: RecorderEvent) => void) | null = null;
  onstop: (() => void) | null = null;

  constructor(
    readonly stream: MediaStream,
    options: MediaRecorderOptions
  ) {
    this.mimeType = options.mimeType ?? 'audio/webm';
  }

  start() {
    this.state = 'recording';
  }

  pause() {
    this.state = 'paused';
  }

  resume() {
    this.state = 'recording';
  }

  stop() {
    this.state = 'inactive';
    this.ondataavailable?.({ data: new Blob(['audio']) });
    this.onstop?.();
  }
}

class MockAudio {
  static instances: MockAudio[] = [];

  src = '';
  currentSrc = '';
  currentTime = 0;
  duration = 2;
  volume = 1;
  playbackRate = 1;
  muted = false;
  paused = true;
  ended = false;
  onended: (() => void) | null = null;

  constructor() {
    MockAudio.instances.push(this);
  }

  play = jest.fn(async () => {
    this.paused = false;
  });

  pause = jest.fn(() => {
    this.paused = true;
  });
}

describe('web entry point', () => {
  const stopTrack = jest.fn();
  const mediaStream = {
    getTracks: () => [{ stop: stopTrack }],
  } as unknown as MediaStream;

  beforeAll(() => {
    Object.defineProperty(global, 'MediaRecorder', {
      configurable: true,
      value: MockMediaRecorder,
    });
    Object.defineProperty(global, 'Audio', {
      configurable: true,
      value: MockAudio,
    });
    Object.defineProperty(global, 'navigator', {
      configurable: true,
      value: {
        mediaDevices: {
          getUserMedia: jest.fn().mockResolvedValue(mediaStream),
        },
      },
    });
  });

  beforeEach(() => {
    jest.clearAllMocks();
    MockAudio.instances = [];
  });

  it('records, pauses, resumes, stops, and releases the microphone', async () => {
    const sound = createSound();

    await expect(sound.startRecorder()).resolves.toBe('recording_in_progress');
    await expect(sound.pauseRecorder()).resolves.toBe('paused');
    await expect(sound.resumeRecorder()).resolves.toBe('resumed');
    await expect(sound.stopRecorder()).resolves.toMatch(/^blob:/);

    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledWith({
      audio: expect.objectContaining({
        channelCount: 1,
        sampleRate: 44100,
      }),
    });
    expect(stopTrack).toHaveBeenCalledTimes(1);
  });

  it('controls playback and clamps volume without leaking player state', async () => {
    const sound = createSound();

    await expect(sound.setVolume(2)).resolves.toBe('1');
    await expect(sound.startPlayer('file:///recording.m4a')).resolves.toBe(
      'file:///recording.m4a'
    );

    const audio = MockAudio.instances[0]!;
    expect(audio.volume).toBe(1);
    await expect(sound.seekToPlayer(1250)).resolves.toBe('1250');
    expect(audio.currentTime).toBe(1.25);
    await expect(sound.setPlaybackSpeed(1.5)).resolves.toBe('1.5');
    expect(audio.playbackRate).toBe(1.5);
    await expect(sound.pausePlayer()).resolves.toBe('paused');
    await expect(sound.resumePlayer()).resolves.toBe('resumed');
    await expect(sound.stopPlayer()).resolves.toBe('stopped');
    await expect(sound.stopPlayer()).resolves.toBe('stopped');
  });

  it('emits an exact playback-end event and formats durations', async () => {
    const sound = createSound();
    const onPlaybackEnd = jest.fn();
    sound.addPlaybackEndListener(onPlaybackEnd);

    await sound.startPlayer('https://example.com/audio.mp3');
    const audio = MockAudio.instances[0]!;
    audio.duration = 2.5;
    audio.currentTime = 2.5;
    audio.onended?.();

    expect(onPlaybackEnd).toHaveBeenCalledWith({
      duration: 2500,
      currentPosition: 2500,
    });
    expect(sound.mmss(65)).toBe('01:05');
    expect(sound.mmssss(65_430)).toBe('01:05:43');
  });

  it('creates independent web instances', () => {
    const first = createSound();
    const second = createSound();

    expect(first).not.toBe(second);
    expect(first.name).toBe('Sound');
    expect(first.equals(first)).toBe(true);
    expect(first.equals(second)).toBe(false);
  });
});
