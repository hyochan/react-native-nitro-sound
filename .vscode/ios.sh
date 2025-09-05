#!/bin/bash

echo "🚀 Starting iOS app..."

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

# Force clean install if react-native is missing
if [ ! -d "$EXAMPLE_DIR/node_modules/react-native/scripts" ]; then
  echo "⚠️  React Native scripts missing, performing clean install..."
  rm -rf node_modules example/node_modules
  yarn install || {
    echo "❌ Workspace yarn install failed"
    exit 1
  }
fi

# Regular check for node_modules
if [ ! -d "node_modules" ] || [ ! -d "example/node_modules" ]; then
  echo "Installing workspace dependencies..."
  yarn install || {
    echo "❌ Workspace yarn install failed"
    exit 1
  }
fi

# 2) Regenerate Nitro bindings at repo root
echo "🧬 Running Nitrogen codegen..."
yarn nitrogen || {
  echo "❌ Nitrogen codegen failed"
  exit 1
}

# 3) Final verification of critical files
if [ ! -f "$EXAMPLE_DIR/node_modules/react-native/scripts/react_native_pods.rb" ]; then
  echo "⚠️  Critical React Native files still missing after install"
  echo "Running clean workspace install..."
  cd "$ROOT_DIR"
  rm -rf node_modules example/node_modules
  yarn cache clean
  yarn install || {
    echo "❌ Clean workspace install failed"
    exit 1
  }
  
  # Final check
  if [ ! -f "$EXAMPLE_DIR/node_modules/react-native/scripts/react_native_pods.rb" ]; then
    echo "❌ Failed to install React Native properly. Please run 'yarn install' manually from project root."
    exit 1
  fi
fi

# 4) Install iOS Pods in example
echo "📦 Installing iOS pods in example..."
cd "$EXAMPLE_DIR/ios"

# Clean pods if needed
if [ -d "Pods" ] && [ ! -f "$EXAMPLE_DIR/node_modules/react-native/scripts/react_native_pods.rb" ]; then
  echo "⚠️  Cleaning invalid Pods directory..."
  rm -rf Pods Podfile.lock
fi

# Run pod install
pod install || {
  echo "⚠️  Pod install failed, trying to clean and retry..."
  pod deintegrate
  pod install || {
    echo "❌ Pod install failed after retry"
    exit 1
  }
}

# 5) Navigate to example directory to run Metro and the app
cd "$EXAMPLE_DIR"

# Check if Metro is already running
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

# 6) Run iOS app on simulator
echo "📱 Building and launching iOS app on simulator..."
yarn ios --simulator="iPhone 16"

# Keep terminal open if there's an error
if [ $? -ne 0 ]; then
    echo "❌ Failed to run iOS app"
    read -p "Press any key to exit..."
fi
