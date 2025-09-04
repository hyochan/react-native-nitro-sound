#!/bin/bash

echo "🚀 Starting iOS app..."

# 1) Regenerate Nitro bindings at repo root
echo "🧬 Running Nitrogen codegen..."
ROOT_DIR="$(dirname "$0")/.."
pushd "$ROOT_DIR" >/dev/null
yarn nitrogen || {
  echo "❌ Nitrogen codegen failed"; exit 1;
}
popd >/dev/null

# 2) Install iOS Pods in example (via npx pod-install)
echo "📦 Installing iOS pods in example..."
pushd "$(dirname "$0")/../example" >/dev/null
npx pod-install || {
  echo "❌ pod-install failed"; exit 1;
}
popd >/dev/null

# 3) Navigate to example directory to run Metro and the app
cd "$(dirname "$0")/../example"

# Check if Metro is already running
if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null ; then
    echo "✅ Metro bundler is already running on port 8081"
else
    echo "🚀 Starting Metro bundler..."
    yarn start --reset-cache > /dev/null 2>&1 &
    # Wait for metro to start by polling the port
    until lsof -i:8081 -t >/dev/null 2>&1; do sleep 0.5; done
fi

# Run iOS app on simulator
echo "📱 Building and launching iOS app on simulator..."
yarn ios --simulator="iPhone 16"

# Keep terminal open if there's an error
if [ $? -ne 0 ]; then
    echo "❌ Failed to run iOS app"
    read -p "Press any key to exit..."
fi
