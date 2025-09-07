import { useMemo, useState } from 'react';
import { useSoundRecorder } from './useSoundRecorder';
import type { UseSoundRecorderOptions } from './useSoundRecorder';
import type { RecordBackType } from './specs/Sound.nitro';

export type UseSoundRecorderState = {
  isRecording: boolean;
  currentPosition: number; // ms
};

export type UseSoundRecorderWithStates = ReturnType<typeof useSoundRecorder> & {
  state: UseSoundRecorderState;
};

export function useSoundRecorderWithStates(
  options: UseSoundRecorderOptions = {}
): UseSoundRecorderWithStates {
  const [state, setState] = useState<UseSoundRecorderState>({
    isRecording: false,
    currentPosition: 0,
  });

  const base = useSoundRecorder({
    ...options,
    onRecord: (e: RecordBackType & { ended?: boolean }) => {
      options.onRecord?.(e);
      setState((s) => ({
        ...s,
        isRecording: e.isRecording ?? true,
        currentPosition: e.currentPosition ?? s.currentPosition,
      }));
      if (e.ended) {
        setState((s) => ({ ...s, isRecording: false }));
      }
    },
  });

  return useMemo(
    () => ({
      ...base,
      state,
    }),
    [base, state]
  );
}

// Alias
export { useSoundRecorderWithStates as useAudioRecorderWithStates };
