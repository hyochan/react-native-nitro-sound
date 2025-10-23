const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

const appDirectory = path.resolve(__dirname);
const compileNodeModules = [
  'react-native-web',
  'react-native-nitro-sound',
  '@react-native-community/slider',
].map((moduleName) => path.resolve(appDirectory, `node_modules/${moduleName}`));

const babelLoaderConfiguration = {
  test: /\.(js|jsx|ts|tsx)$/,
  include: [
    path.resolve(appDirectory, 'index.web.js'),
    path.resolve(appDirectory, 'src'),
    path.resolve(appDirectory, '../src'),
    ...compileNodeModules,
  ],
  use: {
    loader: 'babel-loader',
    options: {
      cacheDirectory: false,
      cacheCompression: false,
      presets: ['@react-native/babel-preset'],
      plugins: ['react-native-web'],
    },
  },
};

const imageLoaderConfiguration = {
  test: /\.(gif|jpe?g|png|svg)$/,
  use: {
    loader: 'url-loader',
    options: {
      name: '[name].[ext]',
    },
  },
};

module.exports = {
  entry: path.resolve(appDirectory, 'index.web.js'),
  output: {
    filename: 'bundle.[contenthash].js',
    path: path.resolve(appDirectory, 'dist'),
    clean: true,
    // Use relative paths so GitHub Pages under /<repo>/ works
    publicPath: './',
  },
  cache: false,
  module: {
    rules: [babelLoaderConfiguration, imageLoaderConfiguration],
  },
  resolve: {
    extensions: [
      '.web.tsx',
      '.web.ts',
      '.web.jsx',
      '.web.js',
      '.tsx',
      '.ts',
      '.jsx',
      '.js',
    ],
    alias: {
      // Force a single React/DOM instance from the example app to avoid hook errors
      'react': path.resolve(__dirname, 'node_modules/react'),
      'react-dom': path.resolve(__dirname, 'node_modules/react-dom'),
      'react/jsx-runtime': path.resolve(
        __dirname,
        'node_modules/react/jsx-runtime.js'
      ),
      'react-native$': 'react-native-web',
      'react-native-nitro-modules': path.resolve(
        __dirname,
        'node_modules/react-native-nitro-modules/lib/module/index.web.js'
      ),
      'react-native-nitro-sound': path.resolve(
        __dirname,
        '../lib/module/index.web.js'
      ),
    },
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: path.resolve(appDirectory, 'public/index.html'),
    }),
    // Copy static assets from public to dist (excluding index.html handled by HtmlWebpackPlugin)
    new CopyWebpackPlugin({
      patterns: [
        {
          from: path.resolve(appDirectory, 'public'),
          to: path.resolve(appDirectory, 'dist'),
          filter: (resourcePath) => !resourcePath.endsWith('index.html'),
        },
      ],
    }),
  ],
  devServer: {
    static: {
      directory: path.resolve(appDirectory, 'public'),
    },
    hot: true,
    open: true,
  },
};
