import { PermissionsAndroid, Platform } from 'react-native';

export async function requestMicrophonePermission(): Promise<boolean> {
  if (Platform.OS !== 'android') return true;

  const result = await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.RECORD_AUDIO
  );
  return result === PermissionsAndroid.RESULTS.GRANTED;
}
