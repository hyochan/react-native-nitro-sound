import { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { HomeScreen, type ScreenKey } from './screens/HomeScreen';
import { SoundHookScreen } from './screens/SoundHookScreen';
import { SoundHookStatesScreen } from './screens/SoundHookStatesScreen';
import { SoundScreen } from './screens/SoundScreen';
import { RapidSwitchScreen } from './screens/RapidSwitchScreen';
import { CompatibilityScreen } from './screens/CompatibilityScreen';
import {
  SafeAreaProvider,
  useSafeAreaContext,
} from './components/SafeAreaContext';

function AppInner() {
  const [screen, setScreen] = useState<ScreenKey | 'Home'>('Home');
  const insets = useSafeAreaContext();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      {screen === 'Home' && <HomeScreen onNavigate={(k) => setScreen(k)} />}
      {screen === 'SoundHook' && (
        <SoundHookScreen onBack={() => setScreen('Home')} />
      )}
      {screen === 'SoundHookStates' && (
        <SoundHookStatesScreen onBack={() => setScreen('Home')} />
      )}
      {screen === 'SoundDirect' && (
        <SoundScreen onBack={() => setScreen('Home')} />
      )}
      {screen === 'RapidSwitch' && (
        <RapidSwitchScreen onBack={() => setScreen('Home')} />
      )}
      {screen === 'Compatibility' && (
        <CompatibilityScreen onBack={() => setScreen('Home')} />
      )}
    </View>
  );
}

const App = () => (
  <SafeAreaProvider>
    <AppInner />
  </SafeAreaProvider>
);

export default App;

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
