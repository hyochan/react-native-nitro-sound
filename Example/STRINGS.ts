import LocalizedStrings from 'react-native-localization';

const strings: any = new LocalizedStrings({
  en: {
    TITLE: 'Audio Recorder Player',
    PLAY: 'Play',
    PAUSE: 'Pause',
    STOP: 'Stop',
    RECORD: 'Record',
  },
  ko: {
    TITLE: '오디오 녹음 / 플레이어',
    PLAY: '재생',
    PAUSE: '일시정지',
    STOP: '정지',
    RECORD: '녹화',
  },
});

export const getString = (str: string) => {
  return strings[str];
};
