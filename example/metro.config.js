const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const root = path.resolve(__dirname, '..');
const pak = require('../package.json');

const config = {
  projectRoot: __dirname,
  watchFolders: [root],

  resolver: {
    // Block react and react-native from parent to avoid duplicate modules
    blockList: [
      new RegExp(`${root}/node_modules/react/.*`),
      new RegExp(`${root}/node_modules/react-native/.*`),
    ],

    extraNodeModules: new Proxy(
      {},
      {
        get: (target, name) => {
          if (name === pak.name) {
            return root;
          }
          return path.join(__dirname, `node_modules/${name}`);
        },
      }
    ),
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
