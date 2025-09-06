# Contribution Guide

## Issue

- Please search and register if you already have the issue you want to create. If you have a similar issue, you can add additional comments.
- Please write a problem or suggestion in the issue. Never include more than one item in an issue.
- Please be as detailed and concise as possible.
  - If necessary, please take a screenshot and upload an image.

## Pull request(PR)

- Do not modify the code in the `main` branch.
- PR allows only the `dev` branch.
- It is useful to use a topic branch that has the parent `dev` as its parent.

## Development Setup

To contribute to this project, follow these steps to set up your development environment:

```bash
# 1. Clone the repository
git clone https://github.com/hyochan/react-native-nitro-sound.git
cd react-native-nitro-sound

# 2. Install root dependencies
yarn

# 3. Build the library (IMPORTANT: Must be done before running the example)
yarn prepare

# 4. Generate Nitro module code
yarn nitrogen

# 5. Install example dependencies and run the example app
# For iOS:
yarn example ios:pod    # This will install pods using workspace
yarn example ios

# For Android:
yarn example android

# For Web:
yarn example web        # Starts development server at http://localhost:8080
# Or build for production:
yarn example build:web
```

**Important Notes:**

- You must run `yarn prepare` before attempting to run the example app
- The `yarn nitrogen` command generates necessary Nitro module bindings
- For iOS, use `yarn example ios:pod` instead of manually navigating to the ios directory
- All example commands can be run from the root directory using yarn workspaces

### Platform-Specific Requirements

#### iOS Development

- macOS with Xcode 14.0 or later
- iOS 13.0+ deployment target
- CocoaPods installed (`gem install cocoapods`)
- Run on simulator: `yarn example ios`
- Run on device: Open `example/ios/SoundExample.xcworkspace` in Xcode

#### Android Development

- Android Studio
- Android SDK with minimum API level 24
- Java 17
- Run on emulator: `yarn example android`
- Run on device: Enable USB debugging and connect your device

#### Web Development

- Modern web browser (Chrome, Firefox, Safari)
- No additional setup required
- Development server: `yarn example web`
- Production build outputs to `example/dist/`
- Supports hot module replacement for faster development

### Coding Guidelines

Please follow the Coding conventions as much as possible when contributing your code.

- The indent tab is two spaces.
- The class declaration and the `{}` in curly brackets such as function, if, foreach, for, and while should be in the following format. Also if you installed eslint in vscode or in your code editor, it will help you with linting.
  - `{` should be placed in same line and `}` should be placed in next line.

```ts
for (let i = 0; i < 10; i++) {
  ...
}
array.forEach((e) => {
  ...
});
```

- Space before `(` and after `)`.
- **If you find code that does not fit in the coding convention, do not ever try to fix code that is not related to your purpose.**
