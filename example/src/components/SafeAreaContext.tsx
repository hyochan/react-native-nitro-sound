import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';

export { SafeAreaProvider };

export function useSafeAreaContext() {
  return useSafeAreaInsets();
}
