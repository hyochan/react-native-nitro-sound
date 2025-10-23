import { useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Platform,
  PermissionsAndroid,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import Slider from '@react-native-community/slider';
import {
  useSound,
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
} from 'react-native-nitro-sound';

export function SoundHookScreen({ onBack }: { onBack: () => void }) {
  const [recordingPath, setRecordingPath] = useState('');
  const [volume, setVolume] = useState(1.0);
  const [speed, setSpeed] = useState(1.0);
  const [isRecording, setIsRecording] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [playbackPosition, setPlaybackPosition] = useState(0);
  const [recordPosition, setRecordPosition] = useState(0);
  const [isRecordLoading, setIsRecordLoading] = useState(false);
  const [isStopLoading, setIsStopLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState('Loading...');
  const [isPlayLoading, setIsPlayLoading] = useState(false);

  const lastEnded = useRef(false);

  const {
    startRecorder,
    pauseRecorder,
    resumeRecorder,
    stopRecorder,
    startPlayer,
    pausePlayer,
    resumePlayer,
    stopPlayer,
    seekToPlayer,
    setVolume: setVolumeApi,
    setPlaybackSpeed: setPlaybackSpeedApi,
    mmssss,
  } = useSound({
    onRecord: (e) => {
      setIsRecording(e.isRecording ?? true);
      setRecordPosition(e.currentPosition ?? 0);
    },
    onPlayback: (e) => {
      setDuration(e.duration);
      setPlaybackPosition(e.currentPosition);
      const ended =
        e.ended || (e.duration > 0 && e.currentPosition >= e.duration);
      if (ended && !lastEnded.current) {
        lastEnded.current = true;
        setIsPlaying(false);
        setPlaybackPosition(e.duration);
      }
      if (!ended) {
        lastEnded.current = false;
      }
    },
    onPlaybackEnd: (e) => {
      setIsPlaying(false);
      setDuration(e.duration);
      setPlaybackPosition(e.currentPosition);
    },
  });

  const requestPermissions = async () => {
    if (Platform.OS !== 'android') return true;
    const sdk = Platform.Version as number;
    if (sdk >= 33) {
      const res = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO
      );
      return res === PermissionsAndroid.RESULTS.GRANTED;
    }
    const grants = await PermissionsAndroid.requestMultiple([
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
    ]);
    return (
      grants['android.permission.RECORD_AUDIO'] ===
      PermissionsAndroid.RESULTS.GRANTED
    );
  };

  const onStartRecord = async () => {
    if (!(await requestPermissions())) {
      Alert.alert('Permission required', 'Microphone permission needed');
      return;
    }
    const audioSet = {
      AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
      AudioSourceAndroid: AudioSourceAndroidType.MIC,
      AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
      AVNumberOfChannelsKeyIOS: 2,
      AVFormatIDKeyIOS: 'aac' as const,
      AVModeIOS: 'measurement' as const,
    };
    try {
      setIsRecordLoading(true);
      setLoadingMessage('Loading...');
      const uri = await startRecorder(undefined, audioSet, true);
      setRecordingPath(uri);
      setIsRecording(true);
      setRecordPosition(0);
    } catch (e) {
      Alert.alert('Start record error', String(e));
    } finally {
      setIsRecordLoading(false);
    }
  };

  const onStartPlay = async () => {
    try {
      setIsPlayLoading(true);
      const pathToPlay =
        Platform.OS === 'web' && recordingPath === 'recording_in_progress'
          ? undefined
          : recordingPath || undefined;
      await startPlayer(pathToPlay);
      await setVolumeApi(volume);
      await setPlaybackSpeedApi(speed);
      setIsPlaying(true);
    } catch (e) {
      Alert.alert('Play error', String(e));
    } finally {
      setIsPlayLoading(false);
    }
  };

  const onStopRecordPress = async () => {
    try {
      setIsStopLoading(true);
      const path = await stopRecorder();
      setIsRecording(false);
      if (Platform.OS === 'android') {
        Alert.alert('Recording Stopped', `File saved at:\n${path}`);
      }
    } catch (e) {
      Alert.alert('Stop record error', String(e));
    } finally {
      setIsStopLoading(false);
    }
  };

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backBtn}>
          <Text style={styles.backTxt}>{'< Back'}</Text>
        </TouchableOpacity>
        <Text style={styles.title}>NitroSound with Hook</Text>
        <View style={styles.spacer} />
      </View>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.sectionTitle}>Recorder</Text>
        <View style={styles.row}>
          <TouchableOpacity
            style={[
              styles.btn,
              (isRecordLoading || isRecording) && styles.btnDisabled,
            ]}
            onPress={onStartRecord}
            disabled={isRecordLoading || isRecording}
          >
            {isRecordLoading ? (
              <View style={styles.btnContent}>
                <ActivityIndicator
                  size="small"
                  color="#fff"
                  style={styles.spinner}
                />
                <Text style={styles.btnTxt}>{loadingMessage}</Text>
              </View>
            ) : (
              <Text style={styles.btnTxt}>Start</Text>
            )}
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (isRecordLoading || !isRecording) && styles.btnDisabled,
            ]}
            onPress={pauseRecorder}
            disabled={isRecordLoading || !isRecording}
          >
            <Text style={styles.btnTxt}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (isRecordLoading || !isRecording) && styles.btnDisabled,
            ]}
            onPress={resumeRecorder}
            disabled={isRecordLoading || !isRecording}
          >
            <Text style={styles.btnTxt}>Resume</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (!isRecording || isStopLoading) && styles.btnDisabled,
            ]}
            onPress={onStopRecordPress}
            disabled={!isRecording || isStopLoading}
          >
            <View style={styles.btnContent}>
              {isStopLoading && (
                <ActivityIndicator
                  size="small"
                  color="#fff"
                  style={styles.spinner}
                />
              )}
              <Text style={styles.btnTxt}>
                {isStopLoading ? 'Stopping...' : 'Stop'}
              </Text>
            </View>
          </TouchableOpacity>
        </View>
        <Text style={styles.small}>
          Recording: {isRecording ? 'Yes' : 'No'}
        </Text>
        <Text style={styles.small}>
          Record Time: {mmssss(Math.floor(recordPosition))}
        </Text>

        <View style={styles.sep} />
        <Text style={styles.sectionTitle}>Player</Text>
        <Text style={styles.small}>Playing: {isPlaying ? 'Yes' : 'No'}</Text>
        <Text style={styles.small}>
          {mmssss(Math.floor(playbackPosition))} /{' '}
          {mmssss(Math.floor(duration))}
        </Text>
        {Platform.OS === 'ios' ? (
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={Math.max(1, duration)}
            value={playbackPosition}
            onSlidingComplete={(v) => seekToPlayer(v)}
          />
        ) : (
          <View style={styles.androidProgressBar}>
            <View
              style={[
                styles.androidProgressFill,
                {
                  width: `${(playbackPosition / Math.max(1, duration)) * 100}%`,
                },
              ]}
            />
          </View>
        )}
        <View style={styles.row}>
          <TouchableOpacity
            style={[
              styles.btn,
              (isPlayLoading || isPlaying) && styles.btnDisabled,
            ]}
            onPress={onStartPlay}
            disabled={isPlayLoading || isPlaying}
          >
            {isPlayLoading ? (
              <View style={styles.btnContent}>
                <ActivityIndicator
                  size="small"
                  color="#fff"
                  style={styles.spinner}
                />
                <Text style={styles.btnTxt}>Loading...</Text>
              </View>
            ) : (
              <Text style={styles.btnTxt}>Play</Text>
            )}
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (isPlayLoading || !isPlaying) && styles.btnDisabled,
            ]}
            onPress={async () => {
              try {
                await pausePlayer();
                setIsPlaying(false);
              } catch {}
            }}
            disabled={isPlayLoading || !isPlaying}
          >
            <Text style={styles.btnTxt}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (isPlayLoading || isPlaying) && styles.btnDisabled,
            ]}
            onPress={async () => {
              try {
                await resumePlayer();
                setIsPlaying(true);
              } catch {}
            }}
            disabled={isPlayLoading || isPlaying}
          >
            <Text style={styles.btnTxt}>Resume</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (isPlayLoading || (!isPlaying && playbackPosition === 0)) &&
                styles.btnDisabled,
            ]}
            onPress={async () => {
              try {
                await stopPlayer();
              } finally {
                setIsPlaying(false);
              }
            }}
            disabled={isPlayLoading || (!isPlaying && playbackPosition === 0)}
          >
            <Text style={styles.btnTxt}>Stop</Text>
          </TouchableOpacity>
        </View>

        <Text style={styles.sectionTitle}>Volume</Text>
        <Slider
          style={styles.slider}
          minimumValue={0}
          maximumValue={1}
          step={0.01}
          value={volume}
          onValueChange={(v) => setVolume(v)}
          onSlidingComplete={(v) => setVolumeApi(v)}
        />
        <Text style={styles.small}>{Math.round(volume * 100)}%</Text>

        <Text style={styles.sectionTitle}>Speed</Text>
        <Slider
          style={styles.slider}
          minimumValue={0.5}
          maximumValue={2}
          step={0.1}
          value={speed}
          onValueChange={(v) => setSpeed(v)}
          onSlidingComplete={(v) => setPlaybackSpeedApi(v)}
        />
        <Text style={styles.small}>{speed.toFixed(1)}x</Text>

        {recordingPath ? (
          <Text style={styles.path}>File: {recordingPath}</Text>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  header: {
    height: 56,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderColor: '#eee',
  },
  backBtn: { padding: 8 },
  backTxt: { color: '#007AFF' },
  title: { fontSize: 16, fontWeight: '600' },
  container: { padding: 16 },
  sectionTitle: { fontSize: 18, fontWeight: '600', marginTop: 8 },
  row: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginVertical: 8 },
  btn: {
    backgroundColor: '#333',
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderRadius: 6,
  },
  btnDisabled: { opacity: 0.6 },
  btnContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  spinner: { marginRight: 6 },
  btnTxt: { color: 'white' },
  small: { fontSize: 12, color: '#555', marginBottom: 6 },
  sep: { height: 1, backgroundColor: '#eee', marginVertical: 16 },
  slider: { width: '100%', height: 40 },
  path: { marginTop: 10, fontSize: 12, color: '#444' },
  spacer: { width: 60 },
  androidProgressBar: {
    width: '100%',
    height: 6,
    backgroundColor: '#ddd',
    borderRadius: 3,
    marginVertical: 10,
  },
  androidProgressFill: {
    height: 6,
    backgroundColor: '#5f27cd',
    borderRadius: 3,
  },
});
