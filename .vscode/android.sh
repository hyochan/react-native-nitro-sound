#!/bin/bash

echo "🚀 Starting Android app..."

# Helper function to check if directory contains workspace package.json
is_workspace_root() {
  [ -f "$1/package.json" ] && grep -q '"workspaces"' "$1/package.json" 2>/dev/null
}

# Get the absolute paths - handle both launch.json and direct execution
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find the root directory by looking for package.json with workspaces
if is_workspace_root "$SCRIPT_DIR/.."; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif is_workspace_root "$(pwd)/.."; then
  ROOT_DIR="$(cd "$(pwd)/.." && pwd)"
else
  echo "❌ Could not find workspace root directory"
  exit 1
fi

EXAMPLE_DIR="$ROOT_DIR/example"

echo "📍 Working from root: $ROOT_DIR"

# 1) Ensure all dependencies are installed at workspace root
echo "📦 Ensuring workspace dependencies are installed..."
cd "$ROOT_DIR"

# Always check and install dependencies if react-native is missing
if [ ! -f "$EXAMPLE_DIR/node_modules/react-native/scripts/react_native_pods.rb" ]; then
  echo "⚠️  React Native scripts missing, installing dependencies..."
  
  # Clean install to ensure everything is properly linked
  echo "🧹 Cleaning old node_modules..."
  rm -rf node_modules example/node_modules yarn.lock example/yarn.lock
  
  echo "📦 Installing fresh dependencies..."
  yarn install || {
    echo "❌ Workspace yarn install failed"
    exit 1
  }
  
  # Verify installation
  if [ ! -f "$EXAMPLE_DIR/node_modules/react-native/scripts/react_native_pods.rb" ]; then
    echo "⚠️  React Native still not properly installed, trying alternative approach..."
    cd "$EXAMPLE_DIR"
    yarn install || {
      echo "❌ Example yarn install failed"
      exit 1
    }
    cd "$ROOT_DIR"
  fi
else
  echo "✅ Dependencies already installed"
fi

# 2) Regenerate Nitro bindings at repo root
echo "🧬 Running Nitrogen codegen..."
yarn nitrogen || {
  echo "❌ Nitrogen codegen failed"
  exit 1
}

# 3) Navigate to example directory
cd "$EXAMPLE_DIR"

# 4) Check if Metro is already running
if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ Metro bundler is already running on port 8081"
else
    echo "🚀 Starting Metro bundler..."
    yarn start --reset-cache > /dev/null 2>&1 &
    # Wait for metro to start by polling the port
    echo "Waiting for Metro to start..."
    until lsof -i:8081 -t >/dev/null 2>&1; do sleep 0.5; done
    echo "✅ Metro bundler started"
fi

# 5) Check if any device/emulator is connected
if ! adb devices | grep -q "device$"; then
    echo "📱 No Android device/emulator found. Starting emulator..."
    
    # Get first available AVD
    AVD_NAME=$(emulator -list-avds | head -1)
    
    if [ -z "$AVD_NAME" ]; then
        echo "❌ No Android Virtual Device found. Please create one using Android Studio."
        exit 1
    fi
    
    echo "🤖 Starting emulator: $AVD_NAME"
    emulator -avd "$AVD_NAME" -no-snapshot-load > /dev/null 2>&1 &
    
    echo "⏳ Waiting for emulator to boot..."
    adb wait-for-device
    
    # Wait for boot animation to finish
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
        sleep 2
    done
    
    echo "✅ Emulator ready"
fi

# 6) Clean build cache for fresh build
echo "🧹 Cleaning Android build cache..."
cd android
./gradlew clean || {
  echo "⚠️  Clean failed, continuing anyway..."
}
cd ..

# 7) Run Android app
echo "🤖 Building and launching Android app..."
yarn android

# Keep terminal open if there's an error
if [ $? -ne 0 ]; then
    echo "❌ Failed to run Android app"
    echo "Common issues:"
    echo "  - Check if Android SDK is properly installed"
    echo "  - Verify ANDROID_HOME environment variable is set"
    echo "  - Make sure Android build tools are up to date"
    read -p "Press any key to exit..."
fi