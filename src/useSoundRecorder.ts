import { useCallback, useEffect, useMemo, useRef } from 'react';
import type { Sound as SoundType, RecordBackType } from './specs/Sound.nitro';
import { ensureSoundActivation } from './utils/sound';

export type UseSoundRecorderOptions = {
  subscriptionDuration?: number; // seconds
  autoDispose?: boolean; // default true
  onRecord?: (e: RecordBackType & { ended?: boolean }) => void;
};

export type UseSoundRecorder = {
  sound: SoundType;
  // Recording controls
  startRecorder: SoundType['startRecorder'];
  pauseRecorder: SoundType['pauseRecorder'];
  resumeRecorder: SoundType['resumeRecorder'];
  stopRecorder: SoundType['stopRecorder'];
  // Utils
  mmss: SoundType['mmss'];
  mmssss: SoundType['mmssss'];
  // Lifecycle
  dispose: () => void;
};

export function useSoundRecorder(
  options: UseSoundRecorderOptions = {}
): UseSoundRecorder {
  const { subscriptionDuration, autoDispose = true } = options;

  const soundRef = useRef<SoundType | null>(null);

  // Configure subscription duration
  useEffect(() => {
    if (subscriptionDuration != null) {
      ensureSoundActivation(soundRef).setSubscriptionDuration(
        subscriptionDuration
      );
    }
  }, [subscriptionDuration]);

  // Wire native record listener to user callback
  useEffect(() => {
    const sound = ensureSoundActivation(soundRef);
    const onRecord = (e: RecordBackType) => {
      options.onRecord?.({ ...e, ended: e.isRecording === false });
    };
    sound.addRecordBackListener(onRecord);
    return () => {
      try {
        sound.removeRecordBackListener();
      } catch {}
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Controls
  const startRecorder = useCallback<SoundType['startRecorder']>(
    async (...args) => ensureSoundActivation(soundRef).startRecorder(...args),
    []
  );
  const pauseRecorder = useCallback<SoundType['pauseRecorder']>(
    async () => ensureSoundActivation(soundRef).pauseRecorder(),
    []
  );
  const resumeRecorder = useCallback<SoundType['resumeRecorder']>(
    async () => ensureSoundActivation(soundRef).resumeRecorder(),
    []
  );
  const stopRecorder = useCallback<SoundType['stopRecorder']>(async () => {
    const res = await ensureSoundActivation(soundRef).stopRecorder();
    options.onRecord?.({
      isRecording: false,
      currentPosition: 0,
      recordSecs: 0,
      ended: true,
    });
    return res;
  }, [options]);

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
      startRecorder,
      pauseRecorder,
      resumeRecorder,
      stopRecorder,
      mmss,
      mmssss,
      dispose,
    }),
    [
      startRecorder,
      pauseRecorder,
      resumeRecorder,
      stopRecorder,
      mmss,
      mmssss,
      dispose,
    ]
  );
}

// Alias with alternative naming preference
export { useSoundRecorder as useAudioRecorder };
