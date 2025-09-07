import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type {
  Sound as SoundType,
  PlayBackType,
  RecordBackType,
} from './specs/Sound.nitro';
import { ensureSoundActivation } from './utils/sound';

export type UseSoundOptions = {
  subscriptionDuration?: number; // seconds (aligns with native API)
  autoDispose?: boolean; // default true, dispose on unmount
  // Optional listeners (forward native events to the app)
  onRecord?: (e: RecordBackType & { ended?: boolean }) => void;
  onPlayback?: (e: PlayBackType & { ended?: boolean }) => void;
  onPlaybackEnd?: (e: { duration: number; currentPosition: number }) => void;
};

export type UseSoundState = {
  isRecording: boolean;
  isPlaying: boolean;
  duration: number; // ms
  currentPosition: number; // ms
};

export type UseSound = {
  sound: SoundType;
  state: UseSoundState;
  // Recording
  startRecorder: SoundType['startRecorder'];
  pauseRecorder: SoundType['pauseRecorder'];
  resumeRecorder: SoundType['resumeRecorder'];
  stopRecorder: SoundType['stopRecorder'];
  // Playback
  startPlayer: SoundType['startPlayer'];
  pausePlayer: SoundType['pausePlayer'];
  resumePlayer: SoundType['resumePlayer'];
  stopPlayer: SoundType['stopPlayer'];
  seekToPlayer: SoundType['seekToPlayer'];
  setVolume: SoundType['setVolume'];
  setPlaybackSpeed: SoundType['setPlaybackSpeed'];
  // Utils
  mmss: SoundType['mmss'];
  mmssss: SoundType['mmssss'];
  // Lifecycle
  dispose: () => void;
};

export function useSound(options: UseSoundOptions = {}): UseSound {
  const { subscriptionDuration, autoDispose = true } = options;

  const soundRef = useRef<SoundType | null>(null);

  const [state, setState] = useState<UseSoundState>({
    isRecording: false,
    isPlaying: false,
    duration: 0,
    currentPosition: 0,
  });

  // Configure subscription duration
  useEffect(() => {
    if (subscriptionDuration != null) {
      ensureSoundActivation(soundRef).setSubscriptionDuration(
        subscriptionDuration
      );
    }
  }, [subscriptionDuration]);

  // Attach listeners: forward native events to user callbacks instead of updating React state
  useEffect(() => {
    const sound = ensureSoundActivation(soundRef);
    const lastRecordRef = { current: null as RecordBackType | null };
    const lastPlaybackRef = { current: null as PlayBackType | null };

    const onRecord: (e: RecordBackType) => void = (e) => {
      lastRecordRef.current = e;
      options.onRecord?.({ ...e, ended: e.isRecording === false });
    };

    const onPlay: (e: PlayBackType) => void = (e) => {
      lastPlaybackRef.current = e;
      const ended = e.duration > 0 && e.currentPosition >= e.duration;
      options.onPlayback?.({ ...e, ended });
      // Only flip coarse flag locally to reflect play/pause status without spamming renders
      if (ended && state.isPlaying) {
        setState((s) => ({ ...s, isPlaying: false }));
      }
    };

    const onPlayEnd = (e: { duration: number; currentPosition: number }) => {
      options.onPlayback?.({
        duration: e.duration,
        currentPosition: e.currentPosition,
        ended: true,
      });
      options.onPlaybackEnd?.(e);
      setState((s) => ({ ...s, isPlaying: false }));
    };

    sound.addRecordBackListener(onRecord);
    sound.addPlayBackListener(onPlay);
    sound.addPlaybackEndListener(onPlayEnd);

    return () => {
      sound.removeRecordBackListener();
      sound.removePlayBackListener();
      sound.removePlaybackEndListener();
    };
    // Intentionally do not include options in deps to avoid re-subscribing per render
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Controls (wrap to update local state eagerly when appropriate)
  const startRecorder = useCallback<SoundType['startRecorder']>(
    async (...args) => {
      const res = await ensureSoundActivation(soundRef).startRecorder(...args);
      setState((s) => ({ ...s, isRecording: true }));
      return res;
    },
    []
  );

  const pauseRecorder = useCallback<SoundType['pauseRecorder']>(async () => {
    const res = await ensureSoundActivation(soundRef).pauseRecorder();
    setState((s) => ({ ...s, isRecording: false }));
    return res;
  }, []);

  const resumeRecorder = useCallback<SoundType['resumeRecorder']>(async () => {
    const res = await ensureSoundActivation(soundRef).resumeRecorder();
    setState((s) => ({ ...s, isRecording: true }));
    return res;
  }, []);

  const stopRecorder = useCallback<SoundType['stopRecorder']>(async () => {
    const res = await ensureSoundActivation(soundRef).stopRecorder();
    setState((s) => ({ ...s, isRecording: false }));
    // Inform consumer that recording ended
    options.onRecord?.({
      isRecording: false,
      currentPosition: 0,
      recordSecs: 0,
      ended: true,
    });
    return res;
  }, [options]);

  const startPlayer = useCallback<SoundType['startPlayer']>(async (...args) => {
    const res = await ensureSoundActivation(soundRef).startPlayer(...args);
    setState((s) => ({ ...s, isPlaying: true }));
    return res;
  }, []);

  const pausePlayer = useCallback<SoundType['pausePlayer']>(async () => {
    const res = await ensureSoundActivation(soundRef).pausePlayer();
    setState((s) => ({ ...s, isPlaying: false }));
    return res;
  }, []);

  const resumePlayer = useCallback<SoundType['resumePlayer']>(async () => {
    const res = await ensureSoundActivation(soundRef).resumePlayer();
    setState((s) => ({ ...s, isPlaying: true }));
    return res;
  }, []);

  const stopPlayer = useCallback<SoundType['stopPlayer']>(async () => {
    const res = await ensureSoundActivation(soundRef).stopPlayer();
    setState((s) => ({ ...s, isPlaying: false, currentPosition: 0 }));
    return res;
  }, []);

  const seekToPlayer = useCallback<SoundType['seekToPlayer']>(async (time) => {
    const res = await ensureSoundActivation(soundRef).seekToPlayer(time);
    setState((s) => ({ ...s, currentPosition: time }));
    return res;
  }, []);

  const setVolume = useCallback<SoundType['setVolume']>(async (v) => {
    return ensureSoundActivation(soundRef).setVolume(v);
  }, []);

  const setPlaybackSpeed = useCallback<SoundType['setPlaybackSpeed']>(
    async (sp) => {
      return ensureSoundActivation(soundRef).setPlaybackSpeed(sp);
    },
    []
  );

  const mmss = useCallback<SoundType['mmss']>(
    (secs) => ensureSoundActivation(soundRef).mmss(secs),
    []
  );
  const mmssss = useCallback<SoundType['mmssss']>(
    (ms) => ensureSoundActivation(soundRef).mmssss(ms),
    []
  );

  const dispose = useCallback(() => {
    try {
      soundRef.current?.dispose();
    } catch {}
    soundRef.current = null;
  }, []);

  useEffect(() => {
    return () => {
      if (autoDispose) dispose();
    };
  }, [autoDispose, dispose]);

  return useMemo(
    () => ({
      sound: ensureSoundActivation(soundRef),
      state,
      startRecorder,
      pauseRecorder,
      resumeRecorder,
      stopRecorder,
      startPlayer,
      pausePlayer,
      resumePlayer,
      stopPlayer,
      seekToPlayer,
      setVolume,
      setPlaybackSpeed,
      mmss,
      mmssss,
      dispose,
    }),
    [
      state,
      startRecorder,
      pauseRecorder,
      resumeRecorder,
      stopRecorder,
      startPlayer,
      pausePlayer,
      resumePlayer,
      stopPlayer,
      seekToPlayer,
      setVolume,
      setPlaybackSpeed,
      mmss,
      mmssss,
      dispose,
    ]
  );
}
