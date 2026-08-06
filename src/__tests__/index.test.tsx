import type { Sound as SoundType } from '../specs/Sound.nitro';

const mockCreateHybridObject = jest.fn();

jest.mock('react-native-nitro-modules', () => ({
  NitroModules: {
    createHybridObject: mockCreateHybridObject,
  },
}));

function createNativeSoundMock() {
  const sound = {
    name: 'Sound',
    startPlayer: jest.fn(function (this: unknown) {
      return Promise.resolve(this === sound ? 'bound' : 'unbound');
    }),
    stopPlayer: jest.fn().mockResolvedValue('stopped'),
  } as unknown as SoundType;

  return sound;
}

describe('native entry point', () => {
  beforeEach(() => {
    jest.resetModules();
    mockCreateHybridObject.mockReset();
  });

  it('creates independent, method-bound HybridObjects', async () => {
    const first = createNativeSoundMock();
    const second = createNativeSoundMock();
    mockCreateHybridObject
      .mockReturnValueOnce(first)
      .mockReturnValueOnce(second);

    const { createSound } = require('../index') as typeof import('../index');
    const firstProxy = createSound();
    const secondProxy = createSound();

    await expect(firstProxy.startPlayer()).resolves.toBe('bound');
    await expect(secondProxy.startPlayer()).resolves.toBe('bound');
    expect(firstProxy).not.toBe(secondProxy);
    expect(mockCreateHybridObject).toHaveBeenNthCalledWith(1, 'Sound');
    expect(mockCreateHybridObject).toHaveBeenNthCalledWith(2, 'Sound');
  });

  it('lazily reuses one HybridObject for the legacy singleton', async () => {
    const nativeSound = createNativeSoundMock();
    mockCreateHybridObject.mockReturnValue(nativeSound);

    const { default: Sound } = require('../index') as typeof import('../index');

    await expect(Sound.startPlayer()).resolves.toBe('bound');
    await expect(Sound.stopPlayer()).resolves.toBe('stopped');
    expect(mockCreateHybridObject).toHaveBeenCalledTimes(1);
  });

  it('preserves the native creation error as context', () => {
    const consoleError = jest
      .spyOn(console, 'error')
      .mockImplementation(() => undefined);
    mockCreateHybridObject.mockImplementation(() => {
      throw new Error('native registration missing');
    });

    const { createSound } = require('../index') as typeof import('../index');

    expect(() => createSound()).toThrow(
      'Failed to create Sound HybridObject: Error: native registration missing'
    );
    expect(consoleError).toHaveBeenCalled();
    consoleError.mockRestore();
  });
});
