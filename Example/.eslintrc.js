module.exports = {
  extends: ['standard', 'plugin:react/recommended'],
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  settings: {
    react: {
      createClass: 'createReactClass',
      pragma: 'React',
      version: 'detect',
    },
  },
  env: {
    browser: true,
    jest: true,
  },
  parserOptions: {
    ecmaVersion: 2017,
    sourceType: 'module',
  },
  rules: {
    'no-unused-vars': 0,
    'jsx-quotes': ['error', 'prefer-single'],
    // '@typescript-eslint/no-unused-vars': 'warn',
    '@typescript-eslint/interface-name-prefix': 'warn',
    '@typescript-eslint/consistent-type-definitions': ['error', 'interface'],
    'no-console': 'error',
    'react/jsx-uses-vars': [2],
    'max-len': [
      2,
      100,
      4,
      {
        ignoreComments: true,
        ignoreUrls: true,
        ignoreRegExpLiterals: true,
      },
    ],
    'comma-dangle': ['error', 'always-multiline'],
    semi: [2, 'always'],
    'arrow-parens': ['error', 'always'],
    'space-before-function-paren': ['error', 'never'],
    'no-new-object': 'error',
    'no-array-constructor': 'error',
    'sort-imports': [
      2,
      {
        ignoreCase: false,
        ignoreMemberSort: false,
        memberSyntaxSortOrder: ['none', 'all', 'multiple', 'single'],
      },
    ],
    'space-before-function-paren': [
      'error',
      {
        anonymous: 'never',
        named: 'never',
        asyncArrow: 'always',
      },
    ],
    'react/prop-types': 0,
  },
};
