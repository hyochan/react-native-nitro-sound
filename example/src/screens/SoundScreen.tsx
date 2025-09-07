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
  createSound,
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
} from '../../../src';

export function SoundScreen({ onBack }: { onBack: () => void }) {
  const soundRef = useRef(createSound());
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
      const uri = await soundRef.current.startRecorder(undefined, audioSet, true);
      setRecordingPath(uri);
      setIsRecording(true);
      setRecordPosition(0);
    } catch (e) {
      Alert.alert('Start record error', String(e));
    } finally {
      setIsRecordLoading(false);
    }

    // Subscribe
    soundRef.current.addRecordBackListener((e) => {
      setIsRecording(e.isRecording ?? true);
      setRecordPosition(e.currentPosition ?? 0);
    });
  };

  const onStopRecord = async () => {
    try {
      setIsStopLoading(true);
      const path = await soundRef.current.stopRecorder();
      setIsRecording(false);
      if (Platform.OS === 'android') {
        Alert.alert('Recording Stopped', `File saved at:\n${path}`);
      }
    } catch (e) {
      Alert.alert('Stop record error', String(e));
    } finally {
      try { soundRef.current.removeRecordBackListener(); } catch {}
      setIsStopLoading(false);
    }
  };

  const onStartPlay = async () => {
    try {
      setIsPlayLoading(true);
      const pathToPlay =
        Platform.OS === 'web' && recordingPath === 'recording_in_progress'
          ? undefined
          : recordingPath || undefined;
      await soundRef.current.startPlayer(pathToPlay);
      await soundRef.current.setVolume(volume);
      await soundRef.current.setPlaybackSpeed(speed);
      setIsPlaying(true);
      // Subscribe
      soundRef.current.addPlayBackListener((e) => {
        setDuration(e.duration);
        setPlaybackPosition(e.currentPosition);
      });
      soundRef.current.addPlaybackEndListener((e) => {
        setIsPlaying(false);
        setDuration(e.duration);
        setPlaybackPosition(e.currentPosition);
      });
    } catch (e) {
      Alert.alert('Play error', String(e));
    } finally {
      setIsPlayLoading(false);
    }
  };

  const onStopPlay = async () => {
    await soundRef.current.stopPlayer();
    setIsPlaying(false);
    try {
      soundRef.current.removePlayBackListener();
      soundRef.current.removePlaybackEndListener();
    } catch {}
  };

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backBtn}>
          <Text style={styles.backTxt}>{'< Back'}</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Direct NitroSound Usage</Text>
        <View style={{ width: 60 }} />
      </View>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.sectionTitle}>Recorder</Text>
        <View style={styles.row}>
          <TouchableOpacity
            style={[styles.btn, (isRecordLoading || isRecording) && styles.btnDisabled]}
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
            style={[styles.btn, (isRecordLoading || !isRecording) && styles.btnDisabled]}
            onPress={() => soundRef.current.pauseRecorder()}
            disabled={isRecordLoading || !isRecording}
          >
            <Text style={styles.btnTxt}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.btn, (isRecordLoading || !isRecording) && styles.btnDisabled]}
            onPress={() => soundRef.current.resumeRecorder()}
            disabled={isRecordLoading || !isRecording}
          >
            <Text style={styles.btnTxt}>Resume</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.btn, (!isRecording || isStopLoading) && styles.btnDisabled]}
            onPress={onStopRecord}
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
        <Text style={styles.small}>Record Time: {ms(recordPosition)}</Text>

        <View style={styles.sep} />
        <Text style={styles.sectionTitle}>Player</Text>
        <Text style={styles.small}>Playing: {isPlaying ? 'Yes' : 'No'}</Text>
        <Text style={styles.small}>
          {ms(playbackPosition)} / {ms(duration)}
        </Text>
        {Platform.OS === 'ios' ? (
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={Math.max(1, duration)}
            value={playbackPosition}
            onSlidingComplete={(v) => soundRef.current.seekToPlayer(v)}
          />
        ) : (
          <View style={styles.androidProgressBar}>
            <View
              style={[
                styles.androidProgressFill,
                {
                  width: `${
                    (playbackPosition / Math.max(1, duration)) * 100
                  }%`,
                },
              ]}
            />
          </View>
        )}
        <View style={styles.row}>
          <TouchableOpacity
            style={[styles.btn, (isPlayLoading || isPlaying) && styles.btnDisabled]}
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
            style={[styles.btn, (isPlayLoading || !isPlaying) && styles.btnDisabled]}
            onPress={async () => {
              try {
                await soundRef.current.pausePlayer();
                setIsPlaying(false);
              } catch {}
            }}
            disabled={isPlayLoading || !isPlaying}
          >
            <Text style={styles.btnTxt}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.btn, (isPlayLoading || isPlaying) && styles.btnDisabled]}
            onPress={async () => {
              try {
                await soundRef.current.resumePlayer();
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
            onPress={onStopPlay}
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
          onSlidingComplete={(v) => soundRef.current.setVolume(v)}
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
          onSlidingComplete={(v) => soundRef.current.setPlaybackSpeed(v)}
        />
        <Text style={styles.small}>{speed.toFixed(1)}x</Text>

        {recordingPath ? (
          <Text style={styles.path}>File: {recordingPath}</Text>
        ) : null}
      </ScrollView>
    </View>
  );
}

function ms(m: number) {
  const s = Math.max(0, Math.floor(m / 1000));
  const mm = String(Math.floor(s / 60)).padStart(2, '0');
  const ss = String(s % 60).padStart(2, '0');
  return `${mm}:${ss}`;
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
  btnTxt: { color: 'white' },
  btnDisabled: { opacity: 0.6 },
  btnContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  spinner: { marginRight: 6 },
  small: { fontSize: 12, color: '#555', marginBottom: 6 },
  sep: { height: 1, backgroundColor: '#eee', marginVertical: 16 },
  slider: { width: '100%', height: 40 },
  path: { marginTop: 10, fontSize: 12, color: '#444' },
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
