// react-native-web has no PermissionsAndroid; the browser prompts for the
// microphone when recording starts.
export async function requestMicrophonePermission(): Promise<boolean> {
  return true;
}
