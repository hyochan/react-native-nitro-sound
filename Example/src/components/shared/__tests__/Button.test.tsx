import 'react-native';

import * as React from 'react';

import {
  RenderResult,
  act,
  fireEvent,
  render,
} from '@testing-library/react-native';
import { ThemeType, createTheme } from '../../../theme';

import Button from '../Button';
import { ThemeProvider } from 'styled-components/native';
// Note: test renderer must be required after react-native.
import renderer from 'react-test-renderer';

let props: any;
let component: React.ReactElement;
let testingLib: RenderResult;

describe('[Button]', () => {
  let cnt = 1;

  beforeEach(() => {
    props = {
      onClick: () => cnt++,
      testID: 'btn',
    };
    component = (
      <ThemeProvider theme={createTheme(ThemeType.LIGHT)}>
        <Button {...props} />
      </ThemeProvider>
    );
  });

  it('renders without crashing', () => {
    const rendered = renderer.create(component).toJSON();
    expect(rendered).toMatchSnapshot();
    expect(rendered).toBeTruthy();
  });

  describe('interactions', () => {
    beforeEach(() => {
      testingLib = render(component);
    });

    it('should simulate onClick', () => {
      const btn = testingLib.queryByTestId('btn');
      act(() => {
        fireEvent.press(btn);
        fireEvent.press(btn);
      });
      expect(cnt).toBe(3);
    });
  });
});
