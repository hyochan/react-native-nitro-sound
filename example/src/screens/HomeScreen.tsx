import {
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Image,
  View,
  Platform,
} from 'react-native';

export type ScreenKey =
  | 'SoundHook'
  | 'SoundHookStates'
  | 'SoundDirect'
  | 'RapidSwitch'
  | 'Compatibility';

export function HomeScreen({
  onNavigate,
}: {
  onNavigate: (k: ScreenKey) => void;
}) {
  // Web: serve from /public directly to avoid bundling issues
  // Native: require local asset
  const logoSource =
    Platform.OS === 'web'
      ? { uri: 'Logo.png' } // relative path works on GitHub Pages under /<repo>/
      : require('../../public/Logo.png');

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View style={styles.header}>
        <Image source={logoSource} style={styles.logo} resizeMode="cover" />
        <Text style={styles.brandTitle}>Nitro Sound</Text>
      </View>
      <Text style={styles.subtitle}>Choose a demo</Text>

      <TouchableOpacity
        testID="e2e-home-hook"
        style={styles.item}
        onPress={() => onNavigate('SoundHook')}
      >
        <Text style={styles.itemTitle}>NitroSound with Hook</Text>
        <Text style={styles.itemDesc}>(Recommended) useSound</Text>
      </TouchableOpacity>

      <TouchableOpacity
        testID="e2e-home-hook-states"
        style={styles.item}
        onPress={() => onNavigate('SoundHookStates')}
      >
        <Text style={styles.itemTitle}>NitroSound with Hook and states</Text>
        <Text style={styles.itemDesc}>useSoundWithStates</Text>
      </TouchableOpacity>

      <TouchableOpacity
        testID="e2e-home-direct"
        style={styles.item}
        onPress={() => onNavigate('SoundDirect')}
      >
        <Text style={styles.itemTitle}>Direct NitroSound Usage</Text>
        <Text style={styles.itemDesc}>createSound factory</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.item}
        onPress={() => onNavigate('RapidSwitch')}
      >
        <Text style={styles.itemTitle}>Rapid Switch Test</Text>
        <Text style={styles.itemDesc}>Switch multiple URLs quickly</Text>
      </TouchableOpacity>

      {Platform.OS !== 'web' && (
        // Note: react-native-video is not supported on web; hide this menu on web
        <TouchableOpacity
          style={styles.item}
          onPress={() => onNavigate('Compatibility')}
        >
          <Text style={styles.itemTitle}>
            Compatibility: react-native-video
          </Text>
          <Text style={styles.itemDesc}>
            Mount Video and start recorder to reproduce iOS issue
          </Text>
        </TouchableOpacity>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 20,
  },
  header: {
    alignItems: 'center',
    marginBottom: 16,
  },
  logo: {
    width: 260,
    height: 260,
    borderRadius: 28,
    marginBottom: 12,
    overflow: 'hidden',
    backgroundColor: 'transparent',
    alignSelf: 'center',
  },
  brandTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 20,
  },
  item: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#eee',
  },
  itemTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 6,
  },
  itemDesc: {
    fontSize: 12,
    color: '#666',
  },
});
