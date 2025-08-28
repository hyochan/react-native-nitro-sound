#!/bin/bash

echo "🚀 Starting Android Emulator..."

# Change to example directory
cd "${BASH_SOURCE%/*}/../example"

# Kill any existing Metro bundler
pkill -f "metro" || true

# Start Metro
echo "🚀 Starting Metro..."
npx react-native start --reset-cache &

# Wait for Metro to start
sleep 5

# Check if emulator is running
if ! adb devices | grep -q "emulator"; then
    echo "📱 Starting Android emulator..."
    # Try to start the first available emulator
    emulator -list-avds | head -1 | xargs -I {} emulator -avd {} -no-snapshot-load &
    
    # Wait for emulator to boot
    echo "⏳ Waiting for emulator to boot..."
    adb wait-for-device
    sleep 10
fi

# Run Android
echo "🤖 Launching Android app..."
npx react-native run-android

# Keep the terminal open
read -p "Press any key to exit..."