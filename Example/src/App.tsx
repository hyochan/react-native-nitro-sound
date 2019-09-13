import { AppProvider as Provider } from './providers';
import React from 'react';
import SwitchNavigator from './components/navigation/SwitchNavigator';

function App(): React.ReactElement {
  return (
    <Provider>
      <SwitchNavigator />
    </Provider>
  );
}

export default App;
