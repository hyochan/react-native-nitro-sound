#!/bin/bash

echo "🚀 Starting iOS Simulator..."

# Change to example directory
cd "${BASH_SOURCE%/*}/../example"

# Kill any existing Metro bundler
pkill -f "metro" || true

# Clean and install pods
echo "🧹 Installing pods..."
cd ios && bundle exec pod install && cd ..

# Clear Metro cache and start
echo "🚀 Starting Metro and launching iOS..."
npx react-native start --reset-cache &

# Wait for Metro to start
sleep 5

# Run iOS
echo "📱 Launching iOS app..."
npx react-native run-ios

# Keep the terminal open
read -p "Press any key to exit..."