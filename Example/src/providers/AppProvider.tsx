import React, { useReducer } from 'react';

import { AppContext } from '../contexts';
import { ThemeType } from '../theme';
import { User } from '../types';

const AppConsumer = AppContext.Consumer;

interface Action {
  type: 'reset-user' | 'set-user' | 'change-theme-mode';
  payload: any;
}

interface Props {
  navigation?: any;
  children?: any;
}

export interface State {
  user: User;
  theme: ThemeType;
}

const initialState: State = {
  theme: ThemeType.LIGHT,
  user: {
    displayName: '',
    age: 0,
    job: '',
  },
};

const reducer = (state: State, action: Action) => {
  switch (action.type) {
    case 'change-theme-mode':
      return { ...state, theme: action.payload.theme };
    case 'reset-user':
      return { ...state, user: initialState.user };
    case 'set-user':
      return { ...state, user: action.payload };
  }
};

function AppProvider(props: Props) {
  const [state, dispatch] = useReducer(reducer, initialState);
  const value = { state, dispatch };

  return (
    <AppContext.Provider value={value}>{props.children}</AppContext.Provider>
  );
}

export { AppConsumer, AppProvider, AppContext };
