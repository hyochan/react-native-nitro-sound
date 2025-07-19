#!/bin/bash
# Fix Nitrogen-generated Swift code that uses C++ std::optional syntax

AUDIO_SET_FILE="nitrogen/generated/ios/swift/AudioSet.swift"

if [ -f "$AUDIO_SET_FILE" ]; then
  echo "Fixing Nitrogen-generated Swift code..."
  
  # Replace has_value() ? pointee : nil pattern with .value
  sed -i '' 's/\.has_value() ? [^:]*\.pointee : nil/.value/g' "$AUDIO_SET_FILE"
  
  echo "✅ Fixed Swift optional syntax in AudioSet.swift"
else
  echo "⚠️  AudioSet.swift not found, skipping fix"
fi