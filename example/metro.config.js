const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const root = path.resolve(__dirname, '..');
const pak = require('../package.json');

// Escape backslashes for Windows
const escapedRoot = root.replace(/\\/g, '\\\\');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  projectRoot: __dirname,
  watchFolders: [root],

  resolver: {
    // Block react and react-native from parent to avoid duplicate modules
    blockList: [
      new RegExp(`${escapedRoot}/node_modules/react/.*`),
      new RegExp(`${escapedRoot}/node_modules/react-native/.*`),
    ],

    extraNodeModules: new Proxy(
      {},
      {
        get: (target, name) => {
          // Redirect react-native-nitro-sound to the parent directory
          if (name === pak.name) {
            return root;
          }
          // Force react and react-native to use example's version
          if (name === 'react' || name === 'react-native') {
            return path.join(__dirname, `node_modules/${name}`);
          }
          return path.join(__dirname, `node_modules/${name}`);
        },
      }
    ),

    // Resolve react-native field from package.json for development
    resolverMainFields: ['react-native', 'browser', 'main'],
  },

  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
