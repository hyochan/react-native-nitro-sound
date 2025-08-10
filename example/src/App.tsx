import { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  Platform,
  PermissionsAndroid,
  SafeAreaView,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import Slider from '@react-native-community/slider';
import AudioRecorderPlayer, {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  OutputFormatAndroidType,
  AVEncoderAudioQualityIOSType,
  type RecordBackType,
  type PlayBackType,
  type PlaybackEndType,
} from '../../src';

const App = () => {
  const [recordSecs, setRecordSecs] = useState(0);
  const [recordTime, setRecordTime] = useState('00:00:00');
  const [playTime, setPlayTime] = useState('00:00:00');
  const [duration, setDuration] = useState('00:00:00');
  const [isRecording, setIsRecording] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [recordingPath, setRecordingPath] = useState('');
  const [recordedDuration, setRecordedDuration] = useState(0); // Store recorded duration
  const [isPlaying, setIsPlaying] = useState(false);
  const [isPlaybackPaused, setIsPlaybackPaused] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isRecordLoading, setIsRecordLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState('Loading...');
  const [isStopLoading, setIsStopLoading] = useState(false);
  const [volume, setVolume] = useState(1.0);
  const [playbackSpeed, setPlaybackSpeed] = useState(1.0);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [totalDuration, setTotalDuration] = useState(0);
  const [isSeeking, setIsSeeking] = useState(false);

  // Helper function to format milliseconds to MM:SS:CS (minutes:seconds:centiseconds)
  const formatTime = (milliseconds: number): string => {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const centiseconds = Math.floor((milliseconds % 1000) / 10); // Convert to centiseconds (0-99)

    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}:${centiseconds.toString().padStart(2, '0')}`;
  };

  useEffect(() => {
    // Check TurboModule registration on mount
    console.log('🚀 === TurboModule Registration Check ===');
    console.log('📱 Platform:', Platform.OS);
    console.log('🏗️ Fabric enabled:', true); // As we can see from your logs
    console.log('📦 AudioRecorderPlayer module exists:', !!AudioRecorderPlayer);

    if (AudioRecorderPlayer) {
      console.log('✅ AudioRecorderPlayer module loaded successfully');
      // Test a simple method to verify it's working
      try {
        const testTime = AudioRecorderPlayer.mmss(60);
        console.log('✅ TurboModule method test successful. Result:', testTime);
      } catch (e) {
        console.log('❌ TurboModule method test failed:', e);
      }
    } else {
      console.log('❌ AudioRecorderPlayer module not found');
    }
    console.log('🚀 === End TurboModule Check ===');

    return () => {
      // Clean up listeners when component unmounts
      try {
        AudioRecorderPlayer.removePlayBackListener();
        AudioRecorderPlayer.removeRecordBackListener();
        AudioRecorderPlayer.removePlaybackEndListener();
      } catch (error) {
        console.log('Error removing listeners:', error);
      }
    };
  }, []);

  const requestPermissions = async () => {
    console.log('🎤 Requesting permissions for platform:', Platform.OS);

    if (Platform.OS === 'android') {
      try {
        // For Android 13+ (API 33+), only RECORD_AUDIO is needed
        const sdkInt = Platform.Version;
        console.log('🎤 Android SDK version:', sdkInt);

        if (sdkInt >= 33) {
          // Android 13+ only needs RECORD_AUDIO
          const granted = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
            {
              title: 'Audio Recording Permission',
              message:
                'This app needs access to your microphone to record audio.',
              buttonNeutral: 'Ask Me Later',
              buttonNegative: 'Cancel',
              buttonPositive: 'OK',
            }
          );

          if (granted === PermissionsAndroid.RESULTS.GRANTED) {
            console.log('🎤 Android RECORD_AUDIO permission granted');
            return true;
          } else {
            console.log('🎤 Android RECORD_AUDIO permission denied:', granted);
            return false;
          }
        } else {
          // Older Android versions need all permissions
          const grants = await PermissionsAndroid.requestMultiple([
            PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
            PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
            PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
          ]);

          console.log('🎤 Permission results:', grants);

          if (
            grants['android.permission.RECORD_AUDIO'] ===
            PermissionsAndroid.RESULTS.GRANTED
          ) {
            console.log('🎤 Android permissions granted');
            return true;
          } else {
            console.log('🎤 Android RECORD_AUDIO permission not granted');
            return false;
          }
        }
      } catch (err) {
        console.warn('🎤 Android permission error:', err);
        return false;
      }
    } else {
      console.log('🎤 iOS - no additional permissions needed');
    }

    console.log('🎤 Permission check completed successfully');
    return true;
  };

  const onStartRecord = async () => {
    console.log('🎤 Starting record process...');

    // Reset recording time when starting new recording
    setRecordSecs(0);
    setRecordTime('00:00:00');
    setIsRecordLoading(true);
    setLoadingMessage('Loading...');

    // First, test if we can access the module at all
    try {
      console.log('🎤 Testing module access...');
      const testTime = AudioRecorderPlayer.mmss(120);
      console.log('🎤 Test mmss result:', testTime);
    } catch (error) {
      console.error('🎤 Module access test failed:', error);
      Alert.alert('Error', `Module not accessible: ${error}`);
      return;
    }

    try {
      console.log('🎤 About to request permissions...');
      const hasPermission = await requestPermissions();
      console.log('🎤 Permissions result:', hasPermission);

      if (!hasPermission) {
        console.error('🎤 Permission not granted');
        setIsRecordLoading(false);
        Alert.alert(
          'Permission Required',
          'Please grant microphone permission to record audio.'
        );
        return;
      }

      console.log('🎤 Creating audio settings...');
    } catch (error) {
      console.error('🎤 Error in permission/settings phase:', error);
      setIsRecordLoading(false);
      Alert.alert('Error', 'Failed to request permissions: ' + String(error));
      return;
    }

    console.log('🎤 About to create audioSet object...');

    let audioSet;
    try {
      console.log('🎤 Checking enum values...');
      console.log('AudioEncoderAndroidType.AAC:', AudioEncoderAndroidType.AAC);
      console.log('AudioSourceAndroidType.MIC:', AudioSourceAndroidType.MIC);
      console.log(
        'AVEncoderAudioQualityIOSType.high:',
        AVEncoderAudioQualityIOSType.HIGH
      );

      audioSet = {
        AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
        AudioSourceAndroid: AudioSourceAndroidType.MIC,
        OutputFormatAndroid: OutputFormatAndroidType.MPEG_4,
        AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.HIGH,
        AVNumberOfChannelsKeyIOS: 2,
        AVFormatIDKeyIOS: 'aac' as const,
      };

      console.log('🎤 Audio settings created successfully:', audioSet);
    } catch (error) {
      console.error('🎤 Error creating audioSet:', error);
      return;
    }

    try {
      console.log('🎤 About to call startRecorder...');
      const uri = await AudioRecorderPlayer.startRecorder(
        undefined,
        audioSet,
        true
      );
      console.log('🎤 Recording started successfully:', uri);
      setRecordingPath(uri);
      setIsRecording(true);
      setIsRecordLoading(false);

      // Set faster update interval for web
      if (Platform.OS === 'web') {
        AudioRecorderPlayer.setSubscriptionDuration(0.01); // 10ms updates
      }

      AudioRecorderPlayer.addRecordBackListener((e: RecordBackType) => {
        console.log('🎤 Recording callback:', e);
        setRecordSecs(Math.floor(e.currentPosition));
        setRecordTime(formatTime(Math.floor(e.currentPosition)));
      });
    } catch (error) {
      console.error('🎤 Start record error:', error);
      console.error('🎤 Error details:', JSON.stringify(error, null, 2));
      setIsRecordLoading(false);

      // Show error message to user
      if (error instanceof Error) {
        Alert.alert('Recording Failed', error.message);
      } else {
        Alert.alert('Recording Failed', 'Unknown error occurred');
      }
    }
  };

  const onPauseRecord = async () => {
    try {
      await AudioRecorderPlayer.pauseRecorder();
      setIsPaused(true);
    } catch (error) {
      console.error('Pause record error:', error);
    }
  };

  const onResumeRecord = async () => {
    try {
      await AudioRecorderPlayer.resumeRecorder();
      setIsPaused(false);
    } catch (error) {
      console.error('Resume record error:', error);
    }
  };

  const onStopRecord = async () => {
    setIsStopLoading(true);

    try {
      // Capture the current recording duration BEFORE stopping
      const finalRecordTime = recordTime;

      const result = await AudioRecorderPlayer.stopRecorder();
      AudioRecorderPlayer.removeRecordBackListener();

      let filePath: string;
      let actualDuration: number;

      // Check if result is an object with duration or just a string
      if (typeof result === 'object' && result !== null) {
        filePath = result.filePath;
        actualDuration = result.duration;
      } else {
        // Fallback for old implementation
        filePath = result as string;
        actualDuration = recordSecs;
      }

      // Use the actual file duration
      setRecordedDuration(actualDuration);

      // Update the display to show actual file duration
      if (actualDuration > 0) {
        setRecordTime(formatTime(actualDuration));
        setRecordSecs(actualDuration);
      }

      // Keep the last recording time display (don't reset)
      setIsRecording(false);
      setIsPaused(false);
      setIsStopLoading(false);
      setRecordingPath(filePath); // Save the recording path

      console.log('=== Recording Stopped ===');
      console.log('File path:', filePath);
      console.log('Recording time before stop:', finalRecordTime);
      console.log('RecordSecs before stop (ms):', recordSecs);
      console.log('Actual file duration from native (ms):', actualDuration);
      console.log(
        'Actual file duration formatted:',
        formatTime(actualDuration)
      );
      console.log('Result type:', typeof result);
      console.log('Full result:', JSON.stringify(result, null, 2));
      console.log('========================');
    } catch (error) {
      console.error('Stop record error:', error);
      setIsStopLoading(false);
    }
  };

  const onStartPlay = async () => {
    if (isPlaying || isLoading) {
      console.log('Already playing or loading, ignoring...');
      return;
    }

    console.log('=== Starting Playback ===');
    console.log('Recording path:', recordingPath);
    console.log('Recorded duration to use:', recordedDuration);
    console.log('Recorded duration formatted:', formatTime(recordedDuration));
    console.log('========================');

    // Reset play time when starting playback (like KMP project)
    setPlayTime('00:00:00');
    setDuration(formatTime(recordedDuration)); // Set to recorded duration right away
    setCurrentPosition(0);
    setTotalDuration(recordedDuration); // Use recorded duration

    setIsLoading(true);
    setLoadingMessage('Loading...');

    try {
      // Set up listener BEFORE starting playback
      console.log('Setting up playback listener...');

      // Set faster update interval for web
      if (Platform.OS === 'web') {
        AudioRecorderPlayer.setSubscriptionDuration(0.01); // 10ms updates
      }

      // Add playback end listener
      AudioRecorderPlayer.addPlaybackEndListener((e: PlaybackEndType) => {
        console.log('📱 Playback ended:', e);
        setIsPlaying(false);
        setIsPlaybackPaused(false);
        setIsLoading(false);

        // Ensure progress bar shows 100% using recorded duration
        const finalDuration = recordedDuration || e.duration || 0;

        // Set position to exactly match duration for 100% progress
        setCurrentPosition(finalDuration);
        setTotalDuration(finalDuration);

        // Also update time displays to show completion
        const finalTimeFormatted = formatTime(finalDuration);
        setPlayTime(finalTimeFormatted);
        setDuration(finalTimeFormatted);
      });

      AudioRecorderPlayer.addPlayBackListener((e: PlayBackType) => {
        // Log only periodically to avoid spam
        if (Math.floor(e.currentPosition) % 1000 < 100) {
          console.log('📱 Playback:', {
            position: formatTime(e.currentPosition),
            fileDuration: formatTime(e.duration),
            recordedDuration: formatTime(recordedDuration),
          });
        }

        // Always use recorded duration for display consistency
        const displayDuration =
          recordedDuration > 0 ? recordedDuration : e.duration;

        // Use actual file duration for playback end detection
        const actualFileDuration = e.duration;

        // Update position and duration states for seeking
        if (!isSeeking) {
          setCurrentPosition(e.currentPosition);
        }
        setTotalDuration(displayDuration);

        setPlayTime(formatTime(Math.floor(e.currentPosition)));
        setDuration(formatTime(Math.floor(displayDuration)));

        // No need to update record time during playback anymore
        // as we already have the actual file duration from stopRecorder

        // Check if playback finished using actual file duration
        const threshold = 100; // 100ms threshold
        if (
          actualFileDuration > 0 &&
          e.currentPosition >= actualFileDuration - threshold
        ) {
          console.log('📱 Playback finished, stopping...');
          console.log(
            '📱 - position:',
            e.currentPosition,
            'actual file duration:',
            actualFileDuration,
            'display duration:',
            displayDuration
          );

          // Update to recorded duration when playback finishes for UI consistency
          const finalDuration = formatTime(Math.floor(displayDuration));
          setPlayTime(finalDuration);
          setDuration(finalDuration);

          // Ensure progress bar shows 100%
          setCurrentPosition(displayDuration);
          setTotalDuration(displayDuration);

          setIsPlaying(false);
          AudioRecorderPlayer.removePlayBackListener();
        }
      });

      console.log('Starting player...');
      console.log('Expected duration from recording:', recordTime);
      // For web, if we get 'recording_in_progress', don't pass any path
      const pathToPlay =
        recordingPath === 'recording_in_progress' ? undefined : recordingPath;
      const msg = await AudioRecorderPlayer.startPlayer(pathToPlay);
      console.log('Started playing:', msg);

      // Hide loading and show playing after player starts
      setIsLoading(false);
      setIsPlaying(true);
      setIsPlaybackPaused(false);

      const volumeResult = await AudioRecorderPlayer.setVolume(1.0);
      console.log('Volume:', volumeResult);
    } catch (error) {
      console.error('Start play error:', error);
      setIsPlaying(false);
      setIsPlaybackPaused(false);
      setIsLoading(false);
    }
  };

  const onPausePlay = async () => {
    try {
      await AudioRecorderPlayer.pausePlayer();
      setIsPlaybackPaused(true);
    } catch (error) {
      console.error('Pause play error:', error);
    }
  };

  const onResumePlay = async () => {
    try {
      await AudioRecorderPlayer.resumePlayer();
      setIsPlaybackPaused(false);
    } catch (error) {
      console.error('Resume play error:', error);
    }
  };

  const onStopPlay = async () => {
    try {
      await AudioRecorderPlayer.stopPlayer();
      AudioRecorderPlayer.removePlayBackListener();
      setPlayTime('00:00:00');
      setDuration('00:00:00');
      setCurrentPosition(0);
      setTotalDuration(0);
      setIsPlaying(false);
      setIsPlaybackPaused(false);
      console.log('Playback stopped');
    } catch (error) {
      console.error('Stop play error:', error);
      setIsPlaying(false);
      setIsPlaybackPaused(false);
    }
  };

  const onSeek = async (value: number) => {
    if (isPlaying || currentPosition > 0) {
      try {
        setIsSeeking(true);
        await AudioRecorderPlayer.seekToPlayer(value);
        setCurrentPosition(value);
        console.log('Seeked to:', value);
      } catch (error) {
        console.error('Seek error:', error);
      } finally {
        setIsSeeking(false);
      }
    }
  };

  const onVolumeChange = async (value: number) => {
    try {
      await AudioRecorderPlayer.setVolume(value);
      setVolume(value);
      console.log('Volume set to:', value);
    } catch (error) {
      console.error('Volume error:', error);
    }
  };

  const onSpeedChange = async (value: number) => {
    try {
      await AudioRecorderPlayer.setPlaybackSpeed(value);
      setPlaybackSpeed(value);
      console.log('Playback speed set to:', value);
    } catch (error) {
      console.error('Speed error:', error);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        <View style={styles.section}>
          <Text style={styles.title}>Audio Recorder</Text>

          <View style={styles.timeContainer}>
            <Text style={styles.timeText}>{recordTime}</Text>
            <Text style={styles.timeLabel}>
              {isRecording
                ? 'Recording...'
                : recordSecs > 0
                  ? 'Recorded'
                  : 'Recording Time'}
            </Text>
          </View>

          <View style={styles.buttonRow}>
            {!isRecording ? (
              <TouchableOpacity
                style={[
                  styles.button,
                  styles.recordButton,
                  isRecordLoading && styles.disabledButton,
                ]}
                onPress={onStartRecord}
                disabled={isRecordLoading}
              >
                {isRecordLoading ? (
                  <View style={styles.loadingContainer}>
                    <ActivityIndicator
                      size="small"
                      color="white"
                      style={styles.loadingSpinner}
                    />
                    <Text style={styles.buttonText}>{loadingMessage}</Text>
                  </View>
                ) : (
                  <Text style={styles.buttonText}>Start Record</Text>
                )}
              </TouchableOpacity>
            ) : (
              <>
                {!isPaused ? (
                  <TouchableOpacity
                    style={[styles.button, styles.pauseButton]}
                    onPress={onPauseRecord}
                  >
                    <Text style={styles.buttonText}>Pause</Text>
                  </TouchableOpacity>
                ) : (
                  <TouchableOpacity
                    style={[styles.button, styles.resumeButton]}
                    onPress={onResumeRecord}
                  >
                    <Text style={styles.buttonText}>Resume</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity
                  style={[
                    styles.button,
                    styles.stopButton,
                    isStopLoading && styles.disabledButton,
                  ]}
                  onPress={onStopRecord}
                  disabled={isStopLoading}
                >
                  <View style={styles.buttonContent}>
                    {isStopLoading && (
                      <ActivityIndicator
                        size="small"
                        color="white"
                        style={styles.loadingSpinner}
                      />
                    )}
                    <Text style={styles.buttonText}>
                      {isStopLoading ? 'Stopping...' : 'Stop'}
                    </Text>
                  </View>
                </TouchableOpacity>
              </>
            )}
          </View>
        </View>

        <View style={styles.separator} />

        <View style={styles.section}>
          <Text style={styles.title}>Audio Player</Text>

          <View style={styles.timeContainer}>
            <Text style={styles.timeText}>
              {playTime} / {duration}
            </Text>
            <Text style={styles.timeLabel}>Playback Time</Text>
          </View>

          {/* Progress Bar for Seeking */}
          {totalDuration > 0 && (
            <View style={styles.progressContainer}>
              <Text style={styles.progressLabel}>Seek Position</Text>
              {Platform.OS === 'ios' ? (
                <Slider
                  style={styles.slider}
                  minimumValue={0}
                  maximumValue={totalDuration}
                  value={currentPosition}
                  onValueChange={(value: number) => setCurrentPosition(value)}
                  onSlidingComplete={onSeek}
                  minimumTrackTintColor="#5f27cd"
                  maximumTrackTintColor="#e0e0e0"
                  thumbTintColor="#5f27cd"
                  disabled={!isPlaying && currentPosition === 0}
                />
              ) : (
                <View style={styles.androidProgressBar}>
                  <View
                    style={[
                      styles.androidProgressFill,
                      {
                        width:
                          totalDuration > 0
                            ? `${Math.min((currentPosition / totalDuration) * 100, 100)}%`
                            : '0%',
                      },
                    ]}
                  />
                </View>
              )}
            </View>
          )}

          {/* Volume Control */}
          <View style={styles.controlContainer}>
            <Text style={styles.controlLabel}>
              Volume: {Math.round(volume * 100)}%
            </Text>
            {Platform.OS === 'ios' ? (
              <Slider
                style={styles.slider}
                minimumValue={0}
                maximumValue={1}
                value={volume}
                onValueChange={onVolumeChange}
                minimumTrackTintColor="#00d2d3"
                maximumTrackTintColor="#e0e0e0"
                thumbTintColor="#00d2d3"
              />
            ) : (
              <Text style={styles.androidNote}>
                Volume control available on iOS
              </Text>
            )}
          </View>

          {/* Playback Speed Control */}
          <View style={styles.controlContainer}>
            <Text style={styles.controlLabel}>
              Speed: {playbackSpeed.toFixed(1)}x
            </Text>
            {Platform.OS === 'ios' ? (
              <Slider
                style={styles.slider}
                minimumValue={0.5}
                maximumValue={2.0}
                value={playbackSpeed}
                onValueChange={onSpeedChange}
                minimumTrackTintColor="#ffa502"
                maximumTrackTintColor="#e0e0e0"
                thumbTintColor="#ffa502"
              />
            ) : (
              <Text style={styles.androidNote}>
                Speed control available on iOS
              </Text>
            )}
          </View>

          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={[
                styles.button,
                styles.playButton,
                (!recordingPath || isPlaying || isLoading || isStopLoading) &&
                  styles.disabledButton,
              ]}
              onPress={onStartPlay}
              disabled={
                !recordingPath || isPlaying || isLoading || isStopLoading
              }
            >
              <View style={styles.buttonContent}>
                {isLoading && (
                  <ActivityIndicator
                    size="small"
                    color="white"
                    style={styles.loadingSpinner}
                  />
                )}
                <Text style={styles.buttonText}>
                  {isLoading
                    ? loadingMessage
                    : isPlaying
                      ? 'Playing...'
                      : 'Play'}
                </Text>
              </View>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.button,
                styles.pauseButton,
                (!isPlaying || isPlaybackPaused) && styles.disabledButton,
              ]}
              onPress={onPausePlay}
              disabled={!isPlaying || isPlaybackPaused}
            >
              <Text style={styles.buttonText}>Pause</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.button,
                styles.resumeButton,
                !isPlaybackPaused && styles.disabledButton,
              ]}
              onPress={onResumePlay}
              disabled={!isPlaybackPaused}
            >
              <Text style={styles.buttonText}>Resume</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.button,
                styles.stopButton,
                !isPlaying && currentPosition === 0 && styles.disabledButton,
              ]}
              onPress={onStopPlay}
              disabled={!isPlaying && currentPosition === 0}
            >
              <Text style={styles.buttonText}>Stop</Text>
            </TouchableOpacity>
          </View>

          {!recordingPath && (
            <View style={styles.instructionContainer}>
              <Text style={styles.instructionText}>
                Please record audio first before playing
              </Text>
            </View>
          )}

          {recordingPath ? (
            <View style={styles.pathContainer}>
              <Text style={styles.pathLabel}>Recording Path:</Text>
              <Text style={styles.pathText}>{recordingPath}</Text>
            </View>
          ) : null}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContainer: {
    flexGrow: 1,
    padding: 20,
  },
  section: {
    marginVertical: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
    color: '#333',
  },
  timeContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
  timeText: {
    fontSize: 32,
    fontWeight: '300',
    color: '#333',
  },
  timeLabel: {
    fontSize: 14,
    color: '#666',
    marginTop: 5,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    flexWrap: 'wrap',
    gap: 10,
  },
  button: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 25,
    marginHorizontal: 5,
    marginVertical: 5,
    minWidth: 100,
    alignItems: 'center',
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  recordButton: {
    backgroundColor: '#ff4757',
  },
  playButton: {
    backgroundColor: '#5f27cd',
  },
  pauseButton: {
    backgroundColor: '#ffa502',
  },
  resumeButton: {
    backgroundColor: '#00d2d3',
  },
  stopButton: {
    backgroundColor: '#747d8c',
  },
  disabledButton: {
    backgroundColor: '#bbb',
    opacity: 0.6,
  },
  instructionContainer: {
    marginTop: 15,
    padding: 10,
    backgroundColor: '#f0f0f0',
    borderRadius: 8,
    alignItems: 'center',
  },
  instructionText: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
  separator: {
    height: 1,
    backgroundColor: '#ddd',
    marginVertical: 30,
  },
  pathContainer: {
    marginTop: 20,
    padding: 15,
    backgroundColor: '#fff',
    borderRadius: 10,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
  pathLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginBottom: 5,
  },
  pathText: {
    fontSize: 12,
    color: '#333',
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingSpinner: {
    marginRight: 8,
  },
  buttonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  progressContainer: {
    marginVertical: 15,
    paddingHorizontal: 20,
  },
  progressLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginBottom: 10,
    textAlign: 'center',
  },
  slider: {
    width: '100%',
    height: 50,
    marginVertical: 10,
  },
  androidProgressBar: {
    width: '100%',
    height: 6,
    backgroundColor: '#ddd',
    borderRadius: 3,
    marginVertical: 15,
  },
  androidProgressFill: {
    height: 6,
    backgroundColor: '#5f27cd',
    borderRadius: 3,
  },
  progressTimeContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 5,
  },
  progressTime: {
    fontSize: 12,
    color: '#666',
  },
  controlContainer: {
    marginVertical: 10,
    paddingHorizontal: 20,
  },
  controlLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginBottom: 5,
    textAlign: 'center',
  },
  androidNote: {
    fontSize: 12,
    color: '#999',
    textAlign: 'center',
    fontStyle: 'italic',
  },
});

export default App;
