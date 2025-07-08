import React, {useState} from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  Platform,
  ScrollView,
  Dimensions,
  PermissionsAndroid,
} from 'react-native';
import {StatusBar} from 'expo-status-bar';
import AudioRecorderPlayer, {
  AVEncoderAudioQualityIOSType,
  AVEncodingOption,
  AudioEncoderAndroidType,
  AudioSet,
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  PlayBackType,
  RecordBackType,
} from 'react-native-audio-recorder-player';
import * as MediaLibrary from 'expo-media-library';

const screenWidth = Dimensions.get('screen').width;

const audioRecorderPlayer = new AudioRecorderPlayer();
audioRecorderPlayer.setSubscriptionDuration(0.025); // 25ms for smoother updates like KMP

export default function App() {
  const [recordTime, setRecordTime] = useState('00:00:00');
  const [currentPositionSec, setCurrentPositionSec] = useState(0);
  const [currentDurationSec, setCurrentDurationSec] = useState(0);
  const [playTime, setPlayTime] = useState('00:00:00');
  const [duration, setDuration] = useState('00:00:00');
  const [recordedUri, setRecordedUri] = useState<string | undefined>();
  const [meteringLevel, setMeteringLevel] = useState(0);

  const onStartRecord = async () => {
    // Request permissions for Android
    if (Platform.OS === 'android') {
      try {
        // For Android 10+ (API 29+), we only need RECORD_AUDIO permission
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
          {
            title: 'Audio Recording Permission',
            message: 'This app needs access to your microphone to record audio.',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          },
        );

        console.log('Record audio permission:', granted);

        if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
          console.log('Audio recording permission denied');
          return;
        }
      } catch (err) {
        console.warn(err);
        return;
      }
    }

    // Request permissions for iOS
    const {status} = await MediaLibrary.requestPermissionsAsync();
    if (status !== 'granted') {
      console.log('Permission to access media library denied');
      return;
    }

    const audioSet: AudioSet = {
      AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
      AudioSourceAndroid: AudioSourceAndroidType.MIC,
      AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
      AVNumberOfChannelsKeyIOS: 2,
      AVFormatIDKeyIOS: AVEncodingOption.aac,
      OutputFormatAndroid: OutputFormatAndroidType.AAC_ADTS,
    };

    // Let the library handle the path, or use undefined to use default path
    const uri = await audioRecorderPlayer.startRecorder(undefined, audioSet, true); // Enable metering
    setRecordedUri(uri);

    audioRecorderPlayer.addRecordBackListener((e: RecordBackType) => {
      setRecordTime(audioRecorderPlayer.mmssss(Math.floor(e.currentPosition)));
      // Metering value is already normalized (0-1 range) on Android
      const meteringValue = e.currentMetering || 0;
      
      // On iOS, metering is in dB (negative values), on Android it's normalized (0-1)
      const normalizedValue = Platform.OS === 'ios' 
        ? Math.max(0, Math.min(1, (meteringValue + 60) / 60))
        : meteringValue;
      
      setMeteringLevel(normalizedValue);
      console.log(`Platform: ${Platform.OS}, Raw metering: ${meteringValue}, Normalized: ${normalizedValue}`);
    });

    console.log(`Recording started at: ${uri}`);
  };

  const onPauseRecord = async () => {
    try {
      await audioRecorderPlayer.pauseRecorder();
    } catch (err) {
      console.log('pauseRecord', err);
    }
  };

  const onResumeRecord = async () => {
    await audioRecorderPlayer.resumeRecorder();
  };

  const onStopRecord = async () => {
    const result = await audioRecorderPlayer.stopRecorder();
    audioRecorderPlayer.removeRecordBackListener();
    setMeteringLevel(0); // Reset meter
    console.log('Recording stopped:', result);
  };

  const onStartPlay = async () => {
    console.log('onStartPlay', recordedUri);

    try {
      const msg = await audioRecorderPlayer.startPlayer(recordedUri);
      const volume = await audioRecorderPlayer.setVolume(1.0);
      console.log(`Started playing: ${msg}`, `volume: ${volume}`);

      audioRecorderPlayer.addPlayBackListener((e: PlayBackType) => {
        console.log(`Playback - Position: ${e.currentPosition}, Duration: ${e.duration}`);
        setCurrentPositionSec(e.currentPosition);
        setCurrentDurationSec(e.duration);
        setPlayTime(audioRecorderPlayer.mmssss(Math.floor(e.currentPosition)));
        setDuration(audioRecorderPlayer.mmssss(Math.floor(e.duration)));
      });
    } catch (err) {
      console.log('startPlayer error', err);
    }
  };

  const onPausePlay = async () => {
    await audioRecorderPlayer.pausePlayer();
  };

  const onResumePlay = async () => {
    await audioRecorderPlayer.resumePlayer();
  };

  const onStopPlay = async () => {
    console.log('onStopPlay');
    audioRecorderPlayer.stopPlayer();
    audioRecorderPlayer.removePlayBackListener();
  };

  const onSeek = (position: number) => {
    if (currentDurationSec > 0) {
      const newPosition = Math.round(position * currentDurationSec);
      audioRecorderPlayer.seekToPlayer(newPosition);
    }
  };

  let playWidth = 0;
  if (currentDurationSec > 0 && currentPositionSec >= 0) {
    const progress = Math.min(currentPositionSec / currentDurationSec, 1.0);
    playWidth = progress * (screenWidth - 56);
  }

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        <Text style={styles.titleTxt}>🎙️ Audio Recorder Player</Text>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Recording</Text>
          <Text style={styles.txtRecordCounter}>{recordTime}</Text>

          {/* Recording meter */}
          <View style={styles.meterContainer}>
            <View style={styles.viewBar}>
              <View
                style={[
                  styles.viewBarMeter,
                  {width: meteringLevel * (screenWidth - 56)},
                ]}
              />
            </View>
          </View>

          <View style={styles.btnRow}>
            <TouchableOpacity style={styles.btn} onPress={onStartRecord}>
              <Text style={styles.txt}>Record</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.btn} onPress={onPauseRecord}>
              <Text style={styles.txt}>Pause</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.btn} onPress={onResumeRecord}>
              <Text style={styles.txt}>Resume</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.btn} onPress={onStopRecord}>
              <Text style={styles.txt}>Stop</Text>
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Playback</Text>
          <Text style={styles.txtRecordCounter}>
            {playTime} / {duration}
          </Text>

          <TouchableOpacity
            style={styles.meterContainer}
            onPress={(e: any) => {
              const touchX = e.nativeEvent.locationX;
              const ratio = touchX / (screenWidth - 56);
              onSeek(ratio);
            }}>
            <View style={styles.viewBar}>
              <View style={[styles.viewBarPlay, {width: playWidth}]} />
            </View>
          </TouchableOpacity>

          <View style={styles.btnRow}>
            <TouchableOpacity style={styles.btn} onPress={onStartPlay}>
              <Text style={styles.txt}>Play</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.btn} onPress={onPausePlay}>
              <Text style={styles.txt}>Pause</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.btn} onPress={onResumePlay}>
              <Text style={styles.txt}>Resume</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.btn} onPress={onStopPlay}>
              <Text style={styles.txt}>Stop</Text>
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.infoSection}>
          <Text style={styles.infoText}>
            {recordedUri ? `Recorded file: ${recordedUri}` : 'No recording yet'}
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#2C3E50',
  },
  scrollContainer: {
    paddingTop: 60,
    paddingBottom: 40,
    alignItems: 'center',
  },
  titleTxt: {
    marginTop: 20,
    marginBottom: 40,
    color: 'white',
    fontSize: 28,
    fontWeight: 'bold',
  },
  section: {
    width: '100%',
    paddingHorizontal: 20,
    marginBottom: 40,
    alignItems: 'center',
  },
  sectionTitle: {
    color: '#BDC3C7',
    fontSize: 18,
    marginBottom: 20,
    fontWeight: '600',
  },
  btnRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 10,
  },
  btn: {
    backgroundColor: '#3498DB',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    margin: 5,
  },
  txt: {
    color: 'white',
    fontSize: 16,
    fontWeight: '500',
  },
  txtRecordCounter: {
    marginBottom: 20,
    color: 'white',
    fontSize: 24,
    fontWeight: '300',
    fontFamily: Platform.OS === 'ios' ? 'Helvetica Neue' : 'monospace',
    letterSpacing: 3,
  },
  viewBar: {
    backgroundColor: '#555',
    height: 6,
    alignSelf: 'stretch',
    borderRadius: 3,
    overflow: 'hidden',
  },
  viewBarPlay: {
    backgroundColor: '#3498DB',
    height: 6,
    borderRadius: 3,
  },
  meterContainer: {
    marginVertical: 15,
    marginHorizontal: 28,
    alignSelf: 'stretch',
  },
  viewBarMeter: {
    backgroundColor: '#E74C3C',
    height: 6,
    borderRadius: 3,
  },
  infoSection: {
    paddingHorizontal: 20,
    paddingTop: 20,
    borderTopWidth: 1,
    borderTopColor: '#34495E',
    width: '100%',
  },
  infoText: {
    color: '#95A5A6',
    fontSize: 12,
    textAlign: 'center',
  },
});
