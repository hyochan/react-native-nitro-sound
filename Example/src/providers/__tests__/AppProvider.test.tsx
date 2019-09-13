import 'react-native';

import * as React from 'react';

import { AppProvider } from '../AppProvider';
// Note: test renderer must be required after react-native.
import renderer from 'react-test-renderer';

describe('[AppProvider] rendering test', () => {
  let json: renderer.ReactTestRendererJSON;
  const component = <AppProvider />;

  it('component and snapshot matches', () => {
    json = renderer.create(component).toJSON();
    expect(json).toMatchSnapshot();
  });
});

describe('[AppProvider] interactions', () => {
  let props;
  let rendered: renderer.ReactTestRenderer;
  // let root: renderer.ReactTestInstance;
  const component = <AppProvider />;

  // const user = {
  //   displayName: 'dooboolab',
  //   age: 30,
  //   job: '',
  // };

  beforeEach(() => {
    props = {
      navigation: {
        navigate: jest.fn(),
      },
    };
    rendered = renderer.create(component);
    // root = rendered.root;
  });

  // it('should trigger [resetUser] action', () => {
  //   let instance = root.instance;
  //   instance.actions.resetUser();
  // });

  // it('should check trigger actions when method called', () => {
  //   let instance = root.instance;
  //   instance.actions.setUser({
  //     displayName: '',
  //     age: 0,
  //     job: '',
  //   });
  // });
});
