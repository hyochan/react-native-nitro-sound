import React, { useContext } from 'react';
import { Theme, createTheme } from '../../theme';
import { createAppContainer, createSwitchNavigator } from 'react-navigation';

import { AppContext } from '../../contexts';
import RootNavigator from './RootStackNavigator';
import { ThemeProvider } from 'styled-components';

const SwitchNavigator = createSwitchNavigator(
  {
    RootNavigator,
  },
  {
    initialRouteName: 'RootNavigator',
  },
);

const AppContainer = createAppContainer(SwitchNavigator);

export interface ScreenProps {
  theme: Theme;
}

export default function Navigator() {
  const { state } = useContext(AppContext);
  const { theme } = state;

  return (
    <ThemeProvider theme={createTheme(theme)}>
      <AppContainer screenProps={{ theme: createTheme(theme) }} />
    </ThemeProvider>
  );
}
