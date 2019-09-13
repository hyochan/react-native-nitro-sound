import 'react-native';

import * as React from 'react';

import {
  RenderResult,
  act,
  fireEvent,
  render,
} from '@testing-library/react-native';
import { ThemeType, createTheme } from '../../../theme';

import { AppProvider } from '../../../providers';
import Button from '../../shared/Button';
import Intro from '../Intro';
// Note: test renderer must be required after react-native.
import { ThemeProvider } from 'styled-components/native';
import renderer from 'react-test-renderer';

const createTestProps = (obj: object) => ({
  navigation: {
    navigate: jest.fn(),
  },
  ...obj,
});

const props: any = createTestProps({});

// test for the container page in dom
describe('[Intro] screen rendering test', () => {
  const component = (
    <AppProvider>
      <ThemeProvider theme={createTheme(ThemeType.LIGHT)}>
        <Intro {...props} />
      </ThemeProvider>
    </AppProvider>
  );
  let json: renderer.ReactTestRendererJSON;

  it('should render outer component and snapshot matches', () => {
    json = renderer.create(component).toJSON();
    expect(json).toMatchSnapshot();
  });
});

describe('[Intro] Interaction', () => {
  const component = (
    <AppProvider>
      <ThemeProvider theme={createTheme(ThemeType.LIGHT)}>
        <Intro {...props} />
      </ThemeProvider>
    </AppProvider>
  );

  let rendered: renderer.ReactTestRenderer;
  let root: renderer.ReactTestInstance;
  let testingLib: RenderResult;

  it('should simulate [onLogin] click', () => {
    rendered = renderer.create(component);
    root = rendered.root;
    testingLib = render(component);

    jest.useFakeTimers();
    const buttons = root.findAllByType(Button);
    act(() => {
      fireEvent.press(testingLib.queryByTestId('btn1'));
      expect(setTimeout).toHaveBeenCalledTimes(1);
      jest.runAllTimers();
    });

    expect(clearTimeout).toHaveBeenCalledTimes(1);
    expect(buttons[0].props.isLoading).toEqual(false);
  });

  it('should simulate [navigate] click', () => {
    rendered = renderer.create(component);
    root = rendered.root;

    // const buttons = root.findAllByType(Button);
    // buttons[1].props.onClick();
    act(() => {
      fireEvent.press(testingLib.getByTestId('btn2'), 'click');
    });
    expect(props.navigation.navigate).toBeCalledWith('Temp');
  });
});
