import { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  PermissionsAndroid,
  Switch,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import VideoSection from '../components/VideoSection';
import {
  useSound,
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
} from 'react-native-nitro-sound';

export function CompatibilityScreen({ onBack }: { onBack: () => void }) {
  const [mountVideo, setMountVideo] = useState(true);
  const [disableVideoAudioSession, setDisableVideoAudioSession] =
    useState(false);
  const [paused, setPaused] = useState(true);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingPath, setRecordingPath] = useState('');
  const [isPlaying, setIsPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [playbackPosition, setPlaybackPosition] = useState(0);
  // VideoSection handles its own duration/position internally (native only)
  const [recordError, setRecordError] = useState<string | null>(null);
  const [recordPosition, setRecordPosition] = useState(0);
  const [isRecordLoading, setIsRecordLoading] = useState(false);
  const [isStopLoading, setIsStopLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState('Loading...');

  const {
    startRecorder,
    pauseRecorder,
    resumeRecorder,
    stopRecorder,
    startPlayer,
    pausePlayer,
    resumePlayer,
    stopPlayer,
    mmssss,
  } = useSound({
    onRecord: (e) => {
      setIsRecording(e.isRecording ?? false);
      setRecordPosition(e.currentPosition ?? 0);
    },
    onPlayback: (e) => {
      setDuration(e.duration);
      setPlaybackPosition(e.currentPosition);
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

  const handleStartRecord = async () => {
    setRecordError(null);
    try {
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
      setIsRecordLoading(true);
      setLoadingMessage('Loading...');
      await startRecorder(undefined, audioSet, true);
      // Enable playing only after recording is finished (on stop)
      setRecordingPath('');
      setIsRecording(true);
      setRecordPosition(0);
    } catch (e) {
      const msg = String(e);
      setRecordError(msg);
      Alert.alert('Start record error', msg);
    } finally {
      setIsRecordLoading(false);
    }
  };

  const handleStopRecord = async () => {
    try {
      setIsStopLoading(true);
      const path = await stopRecorder();
      setRecordingPath(path);
    } catch (e) {
      Alert.alert('Stop record error', String(e));
    } finally {
      setIsRecording(false);
      setIsStopLoading(false);
    }
  };

  const handleStartPlayRecording = async () => {
    if (!recordingPath) {
      Alert.alert('No recording', 'Record something first.');
      return;
    }
    try {
      await startPlayer(recordingPath);
      setIsPlaying(true);
    } catch (e) {
      Alert.alert('Play error', String(e));
    }
  };

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backBtn}>
          <Text style={styles.backTxt}>{'< Back'}</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Compatibility: RN Video</Text>
        <View style={styles.spacer} />
      </View>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.sectionTitle}>Video (react-native-video)</Text>

        <VideoSection
          mountVideo={mountVideo}
          paused={paused}
          onPausedChange={setPaused}
          disableAudioSessionManagement={disableVideoAudioSession}
        />
        <View style={styles.rowBetween}>
          <Text style={styles.small}>Mount Video</Text>
          <Switch value={mountVideo} onValueChange={setMountVideo} />
        </View>
        <View style={styles.rowBetween}>
          <Text style={styles.small}>disableAudioSessionManagement</Text>
          <Switch
            value={disableVideoAudioSession}
            onValueChange={setDisableVideoAudioSession}
          />
        </View>
        <View style={styles.rowBetween}>
          <Text style={styles.small}>Paused</Text>
          <Switch value={paused} onValueChange={setPaused} />
        </View>

        <View style={styles.sep} />

        <Text style={styles.sectionTitle}>Recorder (Nitro Sound)</Text>
        <View style={styles.row}>
          <TouchableOpacity
            style={[
              styles.btn,
              (isRecordLoading || isRecording) && styles.btnDisabled,
            ]}
            onPress={handleStartRecord}
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
            onPress={() => pauseRecorder().catch(() => {})}
            disabled={isRecordLoading || !isRecording}
          >
            <Text style={styles.btnTxt}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (isRecordLoading || !isRecording) && styles.btnDisabled,
            ]}
            onPress={() => resumeRecorder().catch(() => {})}
            disabled={isRecordLoading || !isRecording}
          >
            <Text style={styles.btnTxt}>Resume</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              (!isRecording || isStopLoading) && styles.btnDisabled,
            ]}
            onPress={handleStopRecord}
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

        {recordError ? (
          <Text style={styles.error}>Last error: {recordError}</Text>
        ) : (
          <Text style={styles.small}>
            Tip: On iOS, mount the Video, keep it paused, then try Start Record.
            Toggle disableAudioSessionManagement to compare.
          </Text>
        )}

        <View style={styles.sep} />
        <Text style={styles.sectionTitle}>Player (Nitro Sound)</Text>
        <Text style={styles.small}>
          {mmssss(Math.floor(playbackPosition))} /{' '}
          {mmssss(Math.floor(duration))}
        </Text>
        <View style={styles.row}>
          <TouchableOpacity
            style={[
              styles.btn,
              (!recordingPath || isPlaying || isRecording) &&
                styles.btnDisabled,
            ]}
            onPress={handleStartPlayRecording}
            disabled={!recordingPath || isPlaying || isRecording}
          >
            <Text style={styles.btnTxt}>Play</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.btn, !isPlaying && styles.btnDisabled]}
            onPress={async () => {
              try {
                await pausePlayer();
                setIsPlaying(false);
              } catch {}
            }}
            disabled={!isPlaying}
          >
            <Text style={styles.btnTxt}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.btn, isPlaying && styles.btnDisabled]}
            onPress={async () => {
              try {
                await resumePlayer();
                setIsPlaying(true);
              } catch {}
            }}
            disabled={isPlaying}
          >
            <Text style={styles.btnTxt}>Resume</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.btn,
              !isPlaying && playbackPosition === 0 && styles.btnDisabled,
            ]}
            onPress={async () => {
              try {
                await stopPlayer();
              } finally {
                setIsPlaying(false);
              }
            }}
            disabled={!isPlaying && playbackPosition === 0}
          >
            <Text style={styles.btnTxt}>Stop</Text>
          </TouchableOpacity>
        </View>
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
  spacer: { width: 60 },
  container: { padding: 16 },
  sectionTitle: { fontSize: 18, fontWeight: '600', marginTop: 8 },
  rowBetween: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 6,
  },
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
  sep: { height: 1, backgroundColor: '#eee', marginVertical: 16 },
  // Video styles moved to VideoSection.native.tsx
  small: { fontSize: 12, color: '#555', marginTop: 6 },
  error: { fontSize: 12, color: '#B00020', marginTop: 10 },
  note: { fontSize: 12, color: '#666', marginTop: 8 },
});
