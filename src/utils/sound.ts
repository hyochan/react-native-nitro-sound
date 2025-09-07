import type { MutableRefObject } from 'react';
import type { Sound as SoundType } from '../specs/Sound.nitro';
import { createSound } from '../index';

// Ensures a Sound HybridObject exists in the given ref.
// Recreates it if previously disposed (ref.current === null).
export function ensureSoundActivation(
  ref: MutableRefObject<SoundType | null>
): SoundType {
  if (!ref.current) {
    ref.current = createSound();
  }
  return ref.current;
}
