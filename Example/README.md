### ANNOUNCEMENT

DO NOT MODIFY OR CHANGE THE CODE BEFORE CONFIRMED BY `DOOBOOLAB`. THIS REPOSITORY IS USED IN `DOOBOO-CLI`.

# React Native TS Boilerplate

[![codecov](https://codecov.io/gh/dooboolab/dooboo-native-ts/branch/master/graph/badge.svg)](https://codecov.io/gh/dooboolab/dooboo-native-ts)
[![CircleCI](https://circleci.com/gh/dooboolab/dooboo-native-ts.svg?style=svg)](https://circleci.com/gh/dooboolab/dooboo-native-ts) [![Greenkeeper badge](https://badges.greenkeeper.io/dooboolab/dooboo-native-ts.svg)](https://greenkeeper.io/)

> Specification

- [react-native](https://github.com/facebook/react-native)
- [react-navigation](https://github.com/react-navigation/react-navigation)
- [typescript](https://github.com/Microsoft/TypeScript)
- [localization](https://github.com/stefalda/ReactNativeLocalization)
- [styled-components](https://github.com/styled-components/styled-components)
- [ts-jest](https://github.com/kulshekhar/ts-jest)
- [react-native-testing-library](https://github.com/callstack/react-native-testing-library)
- [react-hook](https://reactjs.org/docs/hooks-intro.html)
- [prettier](https://prettier.io)

### Gain points

```
1. Sample of context-api with `react-hook` (`useContext`).
2. Know how to structure react native app with typescript.
3. Know how to navigate between screens with `react-navigation`.
4. Know how to write test code with `react-native-testing-library`.
5. Know how to `lint` your project with `tslint`.
6. Know how to localize your project.
```

### INSTALL

```
npm install && npm start
// or
yarn && yarn start
```

### Structures

```text
app/
├─ .doobooo // necessary if using dooboo-cli
├─ assets
│  └─ icons // app icons
│  └─ images // app images like background images
├─ node_modules/
├─ src/
│  └─ apis
│  └─ components
│     └─ navigations
│     └─ screen
│     └─ shared
│  └─ contexts
│  └─ utils
│  └─ App.tsx
├─ test/
├─ .buckconfig
├─ .flowconfig
├─ .gitattributes
├─ .gitignore
├─ .watchmanconfig
├─ app.json
├─ babel.config.js
├─ index.js
├─ jest.config.js
├─ package.json
├─ README.md
├─ STRINGS.js
├─ tsconfig.json
└─ eslint.json
```

### Running the project

Running the project is as simple as running

```sh
npm run start
```

This runs the `start` script specified in our `package.json`, and will spawn off a server which reloads the page as we save our files.
Typically the server runs at `http://localhost:8080`, but should be automatically opened for you.

## Testing the project

Testing is also just a command away:

```sh
npm test
```

> Result

```
> jest -u

 PASS  src/components/shared/__tests__/Button.test.tsx
 PASS  src/components/screen/__tests__/Intro.test.tsx
 › 2 snapshots written.

Snapshot Summary
 › 2 snapshots written in 1 test suite.

Test Suites: 2 passed, 2 total
Tests:       5 passed, 5 total
Snapshots:   2 added, 4 passed, 6 total
Time:        3.055s, estimated 6s
Ran all test suites
```

### Writing tests with Jest

We've created test examples with jest-ts in `src/components/screen/__tests__` and `src/components/shared/__tests__`. Since react is component oriented, we've designed to focus on writing test in same level of directory with component. You can simply run `npm test` to test if it succeeds and look more closer opening the source.

### Vscode prettier and eslint setup

```
"eslint.enable": true,
"eslint.validate": [
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact"
],
// prettier extension setting
"editor.formatOnSave": true,
"[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
},
"[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
},
"[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
},
"[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
},
"prettier.singleQuote": true,
"prettier.trailingComma": "all",
"prettier.arrowParens": "always",
"prettier.jsxSingleQuote": true
```

### Localization

We've defined Localization strings in `STRINGS.js` which is in root dir.
We used [react-native-localization](https://github.com/stefalda/ReactNativeLocalization) pacakage for this one.

```
import LocalizedStrings from 'react-native-localization';

const strings = new LocalizedStrings({
  en: {
    LOGIN: 'Login',
  },
  kr: {
    LOGIN: '로그인',
  },
});

export {
  strings,
};
```

Fixed jest setup by adding following in jestSetup.

```
import { NativeModules } from 'react-native';

/**
 * monkey patching the locale to avoid the error:
 * Something went wrong initializing the native ReactLocalization module
 * https://gist.github.com/MoOx/08b465c3eac9e36e683929532472d1e0
 */

NativeModules.ReactLocalization = {
  language: 'en_US',
};
```

### React version

16.8.3

### React Native version

0.60

### React navigation

3
