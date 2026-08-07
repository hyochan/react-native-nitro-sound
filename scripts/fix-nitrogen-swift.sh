#!/usr/bin/env bash
set -euo pipefail
# Fix Nitrogen-generated Swift code that uses C++ std::optional syntax

AUDIO_SET_FILE="nitrogen/generated/ios/swift/AudioSet.swift"

if [ -f "$AUDIO_SET_FILE" ]; then
  echo "Fixing Nitrogen-generated Swift code..."
  
  # Replace has_value() ? pointee : nil pattern with .value
  # Perl's in-place edit works consistently on macOS and Linux CI runners.
  perl -pi -e 's/\.has_value\(\) \? [^:]*\.pointee : nil/.value/g' "$AUDIO_SET_FILE"
  
  echo "✅ Fixed Swift optional syntax in AudioSet.swift"
else
  echo "⚠️  AudioSet.swift not found, skipping fix"
fi
