import { useMemo, useState } from 'react';
import type { UseSound, UseSoundOptions } from './useSound';
import { useSound } from './useSound';
import type { PlayBackType, RecordBackType } from './specs/Sound.nitro';

export type UseSoundWithStatesState = {
  isRecording: boolean;
  isPlaying: boolean;
  playback: { position: number; duration: number };
  recording: { position: number };
};

export type UseSoundWithStates = Omit<UseSound, 'state'> & {
  state: UseSoundWithStatesState;
};

export function useSoundWithStates(
  options: UseSoundOptions = {}
): UseSoundWithStates {
  const [state, setState] = useState<UseSoundWithStatesState>({
    isRecording: false,
    isPlaying: false,
    playback: { position: 0, duration: 0 },
    recording: { position: 0 },
  });

  const base = useSound({
    ...options,
    onRecord: (e: RecordBackType & { ended?: boolean }) => {
      options.onRecord?.(e);
      setState((s) => ({
        ...s,
        isRecording: e.isRecording ?? true,
        recording: {
          position: e.currentPosition ?? s.recording.position,
        },
      }));
    },
    onPlayback: (e: PlayBackType & { ended?: boolean }) => {
      options.onPlayback?.(e);
      const ended =
        e.ended || (e.duration > 0 && e.currentPosition >= e.duration);
      const position = Math.min(
        e.currentPosition ?? 0,
        e.duration ?? Number.MAX_SAFE_INTEGER
      );
      setState((s) => ({
        ...s,
        isPlaying: !ended,
        playback: {
          position,
          duration: e.duration ?? s.playback.duration,
        },
      }));
    },
    onPlaybackEnd: (e) => {
      options.onPlaybackEnd?.(e);
      setState((s) => ({
        ...s,
        isPlaying: false,
        playback: {
          position: e.currentPosition,
          duration: e.duration,
        },
      }));
    },
  });

  // Wrap base controls to keep local state consistent even if native doesn't emit an event.
  const startPlayer: UseSound['startPlayer'] = useMemo(
    () => async (...args) => {
      const res = await base.startPlayer(...args);
      setState((s) => ({ ...s, isPlaying: true }));
      return res;
    },
    [base]
  );
  const pausePlayer: UseSound['pausePlayer'] = useMemo(
    () => async () => {
      const res = await base.pausePlayer();
      setState((s) => ({ ...s, isPlaying: false }));
      return res;
    },
    [base]
  );
  const resumePlayer: UseSound['resumePlayer'] = useMemo(
    () => async () => {
      const res = await base.resumePlayer();
      setState((s) => ({ ...s, isPlaying: true }));
      return res;
    },
    [base]
  );
  const stopPlayer: UseSound['stopPlayer'] = useMemo(
    () => async () => {
      const res = await base.stopPlayer();
      setState((s) => ({
        ...s,
        isPlaying: false,
        playback: { position: 0, duration: s.playback.duration },
      }));
      return res;
    },
    [base]
  );
  const seekToPlayer: UseSound['seekToPlayer'] = useMemo(
    () => async (t) => {
      const res = await base.seekToPlayer(t);
      setState((s) => ({ ...s, playback: { ...s.playback, position: t } }));
      return res;
    },
    [base]
  );

  return useMemo(
    () => ({
      ...base,
      startPlayer,
      pausePlayer,
      resumePlayer,
      stopPlayer,
      seekToPlayer,
      state,
    }),
    [base, startPlayer, pausePlayer, resumePlayer, stopPlayer, seekToPlayer, state]
  );
}
