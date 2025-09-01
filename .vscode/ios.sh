#!/bin/bash

echo "🚀 Starting iOS app..."

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

# Run iOS app on simulator
echo "📱 Building and launching iOS app on simulator..."
yarn ios --simulator="iPhone 16"

# Keep terminal open if there's an error
if [ $? -ne 0 ]; then
    echo "❌ Failed to run iOS app"
    read -p "Press any key to exit..."
fi