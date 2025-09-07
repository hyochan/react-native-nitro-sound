import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { RapidSwitchTest } from '../RapidSwitchTest';

export function RapidSwitchScreen({ onBack }: { onBack: () => void }) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backBtn}>
          <Text style={styles.backTxt}>{'< Back'}</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Rapid Switch Test</Text>
        <View style={styles.spacer} />
      </View>
      <RapidSwitchTest />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    height: 56,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderColor: '#eee',
  },
  backBtn: {
    paddingVertical: 8,
    paddingHorizontal: 8,
  },
  backTxt: { fontSize: 14, color: '#007AFF' },
  title: { fontSize: 16, fontWeight: '600' },
  spacer: { width: 60 },
});
