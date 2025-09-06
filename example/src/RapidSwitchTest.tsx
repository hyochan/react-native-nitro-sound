import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Platform,
  ScrollView,
} from 'react-native';
import Sound from '../../src';

const TEST_AUDIO_URLS = [
  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
];

export const RapidSwitchTest: React.FC = () => {
  const [isTestRunning, setIsTestRunning] = useState(false);
  const [testLog, setTestLog] = useState<string[]>([]);
  const [currentTrack, setCurrentTrack] = useState(-1);

  const addLog = (message: string) => {
    const timestamp = new Date().toLocaleTimeString();
    setTestLog((prev) => [...prev, `${timestamp}: ${message}`]);
  };

  const rapidSwitchTest = async () => {
    setIsTestRunning(true);
    setTestLog([]);
    addLog('Starting rapid switch test...');

    try {
      // Test rapid switching between multiple audio files
      for (let i = 0; i < 10; i++) {
        const trackIndex = i % TEST_AUDIO_URLS.length;
        const url = TEST_AUDIO_URLS[trackIndex];

        addLog(`Starting track ${trackIndex + 1}...`);
        setCurrentTrack(trackIndex);

        try {
          await Sound.startPlayer(url);
          addLog(`Playing track ${trackIndex + 1}`);

          // Play for a very short time (100-500ms)
          await new Promise((resolve) =>
            setTimeout(resolve, Math.random() * 400 + 100)
          );

          addLog(`Stopping track ${trackIndex + 1}...`);
          await Sound.stopPlayer();
          addLog(`Stopped track ${trackIndex + 1}`);

          // Very short delay between switches (0-100ms)
          await new Promise((resolve) =>
            setTimeout(resolve, Math.random() * 100)
          );
        } catch (error) {
          addLog(`ERROR on track ${trackIndex + 1}: ${error}`);
          Alert.alert('Error', `Failed on track ${trackIndex + 1}: ${error}`);
          break;
        }
      }

      addLog('Test completed successfully!');
      Alert.alert('Success', 'Rapid switch test completed without errors!');
    } catch (error) {
      addLog(`Test failed: ${error}`);
      Alert.alert('Test Failed', `${error}`);
    } finally {
      setIsTestRunning(false);
      setCurrentTrack(-1);
      // Ensure player is stopped
      try {
        await Sound.stopPlayer();
      } catch {}
    }
  };

  const stressTest = async () => {
    setIsTestRunning(true);
    setTestLog([]);
    addLog('Starting stress test (immediate switches)...');

    try {
      // Even more aggressive: start/stop immediately without waiting
      for (let i = 0; i < 20; i++) {
        const trackIndex = i % TEST_AUDIO_URLS.length;
        const url = TEST_AUDIO_URLS[trackIndex];

        addLog(`Quick switch ${i + 1}...`);

        try {
          const startPromise = Sound.startPlayer(url);
          const stopPromise = Sound.stopPlayer();

          await Promise.all([startPromise, stopPromise]).catch((err) => {
            // One might fail, but we continue
            addLog(`Concurrent operation ${i + 1}: ${err}`);
          });
        } catch (error) {
          addLog(`ERROR on switch ${i + 1}: ${error}`);
          if (
            error instanceof Error &&
            error.toString().includes('already resolved')
          ) {
            Alert.alert(
              'Bug Found!',
              'Promise already resolved error occurred!'
            );
            throw error;
          }
        }
      }

      addLog('Stress test completed!');
      Alert.alert('Success', 'Stress test completed!');
    } catch (error) {
      addLog(`Stress test failed: ${error}`);
      Alert.alert('Stress Test Failed', `${error}`);
    } finally {
      setIsTestRunning(false);
      // Clean up
      try {
        await Sound.stopPlayer();
      } catch {}
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Rapid Audio Switch Test</Text>
      <Text style={styles.subtitle}>Testing for Promise rejection bug</Text>

      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={[styles.button, isTestRunning && styles.buttonDisabled]}
          onPress={rapidSwitchTest}
          disabled={isTestRunning}
        >
          <Text style={styles.buttonText}>
            {isTestRunning ? 'Test Running...' : 'Start Rapid Switch Test'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.button,
            styles.stressButton,
            isTestRunning && styles.buttonDisabled,
          ]}
          onPress={stressTest}
          disabled={isTestRunning}
        >
          <Text style={styles.buttonText}>
            {isTestRunning ? 'Test Running...' : 'Start Stress Test'}
          </Text>
        </TouchableOpacity>
      </View>

      {currentTrack >= 0 && (
        <Text style={styles.currentTrack}>
          Currently playing: Track {currentTrack + 1}
        </Text>
      )}

      <View style={styles.logContainer}>
        <Text style={styles.logTitle}>Test Log:</Text>
        <ScrollView
          style={styles.logScrollView}
          showsVerticalScrollIndicator={true}
        >
          {testLog.map((log, index) => (
            <Text
              key={index}
              style={[
                styles.logEntry,
                log.includes('ERROR') && styles.errorLog,
                log.includes('SUCCESS') && styles.successLog,
              ]}
            >
              {log}
            </Text>
          ))}
        </ScrollView>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 10,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 20,
    textAlign: 'center',
  },
  buttonContainer: {
    marginBottom: 20,
  },
  button: {
    backgroundColor: '#2196F3',
    padding: 15,
    borderRadius: 8,
    marginBottom: 10,
  },
  stressButton: {
    backgroundColor: '#FF5722',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    textAlign: 'center',
    fontWeight: 'bold',
  },
  currentTrack: {
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
    color: '#4CAF50',
  },
  logContainer: {
    flex: 1,
    backgroundColor: 'white',
    padding: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  logScrollView: {
    flex: 1,
    maxHeight: 400,
  },
  logTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  logEntry: {
    fontSize: 12,
    marginBottom: 5,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  errorLog: {
    color: 'red',
    fontWeight: 'bold',
  },
  successLog: {
    color: 'green',
    fontWeight: 'bold',
  },
});
