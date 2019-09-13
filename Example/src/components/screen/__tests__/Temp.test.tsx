import 'react-native';

import * as React from 'react';

import {
  RenderResult,
  act,
  fireEvent,
  render,
} from '@testing-library/react-native';
import { ThemeType, createTheme } from '../../../theme';

import Temp from '../Temp';
import { ThemeProvider } from 'styled-components/native';
import renderer from 'react-test-renderer';

const props = {
  navigation: {
    goBack: jest.fn(),
  },
};

const component = (
  <ThemeProvider theme={createTheme(ThemeType.LIGHT)}>
    <Temp {...props} />
  </ThemeProvider>
);

describe('[Temp] render', () => {
  it('renders without crashing', () => {
    const rendered = renderer.create(component).toJSON();
    expect(rendered).toMatchSnapshot();
    expect(rendered).toBeTruthy();
  });
});

describe('[Temp] Interaction', () => {
  let renderResult: RenderResult;

  beforeEach(() => {
    renderResult = render(component);
  });

  it('should simulate [onClick] when [btn] has been clicked', () => {
    const btnInstance = renderResult.getByTestId('btn');
    act(() => {
      fireEvent.press(btnInstance);
    });
    expect(props.navigation.goBack).toHaveBeenCalled();
  });
});
