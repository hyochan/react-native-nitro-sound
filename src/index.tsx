import { NitroModules } from 'react-native-nitro-modules';
import type { Sound as SoundType } from './specs/Sound.nitro';

export * from './specs/Sound.nitro';

// Factory: create a new HybridObject instance per call
export function createSound(): SoundType {
  try {
    const inst = NitroModules.createHybridObject<SoundType>('Sound');

    // Proxy to bind methods to the instance
    const proxy = new Proxy(inst as SoundType, {
      get(target, prop: keyof SoundType) {
        const value = (target as any)[prop];

        if (typeof value === 'function') {
          return value.bind(target);
        }
        return value;
      },
    });

    return proxy as SoundType;
  } catch (error) {
    console.error('Failed to create Sound HybridObject:', error);
    throw new Error(`Failed to create Sound HybridObject: ${error}`);
  }
}

// Backward-compatible singleton (legacy API)
let _singleton: SoundType | null = null;
const getSingleton = (): SoundType => {
  if (!_singleton) {
    _singleton = createSound();
  }
  return _singleton;
};

// Proxy object that forwards to the singleton for legacy API
const Sound: SoundType = new Proxy({} as SoundType, {
  get(_target, prop: keyof SoundType) {
    // Ensure instance
    const inst = getSingleton();
    const value = (inst as any)[prop];
    if (typeof value === 'function') {
      return value.bind(inst);
    }
    return value;
  },
}) as SoundType;

export default Sound;
export { Sound };
export { useSound } from './useSound';
export { useSoundWithStates } from './useSoundWithStates';
export { useSoundRecorder, useAudioRecorder } from './useSoundRecorder';
export {
  useSoundRecorderWithStates,
  useAudioRecorderWithStates,
} from './useSoundRecorderWithStates';
