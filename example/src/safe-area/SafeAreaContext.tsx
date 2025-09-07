import React, { createContext, useContext, useMemo } from 'react';
import { Platform, StatusBar } from 'react-native';

export type EdgeInsets = { top: number; right: number; bottom: number; left: number };

const defaultInsets: EdgeInsets = { top: 0, right: 0, bottom: 0, left: 0 };

const SafeAreaContext = createContext<EdgeInsets>(defaultInsets);

export function SafeAreaProvider({ children }: { children: React.ReactNode }) {
  // Lightweight Android-only safe area: use status bar height for top inset.
  // Avoids pulling in react-native-safe-area-context to keep New Arch stable.
  const insets = useMemo<EdgeInsets>(() => {
    if (Platform.OS === 'android') {
      const top = StatusBar.currentHeight ?? 0;
      return { top, right: 0, bottom: 0, left: 0 };
    }
    return defaultInsets;
  }, []);

  return (
    <SafeAreaContext.Provider value={insets}>{children}</SafeAreaContext.Provider>
  );
}

export function useSafeAreaContext() {
  return useContext(SafeAreaContext);
}

