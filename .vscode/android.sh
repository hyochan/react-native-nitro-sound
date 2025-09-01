#!/bin/bash
set -e

echo "🚀 Starting Android app..."

# Navigate to example directory
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

# Check if any device/emulator is connected
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

# Run Android app
echo "🤖 Building and launching Android app..."
yarn android

# Keep terminal open if there's an error
if [ $? -ne 0 ]; then
    echo "❌ Failed to run Android app"
    read -p "Press any key to exit..."
fi