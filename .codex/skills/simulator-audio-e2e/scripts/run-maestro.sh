#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
device_id="${2:-}"

if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
  echo "Usage: $0 <ios|android> <simulator-udid|emulator-serial>" >&2
  exit 2
fi

if [[ -z "$device_id" ]]; then
  echo "An explicit virtual-device identifier is required." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
flow="$repo_root/e2e/maestro/audio-$platform.yaml"
artifact_dir="$repo_root/e2e/artifacts/$platform"
mkdir -p "$artifact_dir"

if [[ "$platform" == "ios" ]]; then
  if ! xcrun simctl list devices booted | grep -F "$device_id" >/dev/null; then
    echo "Refusing to run: $device_id is not a booted iOS Simulator." >&2
    exit 3
  fi
else
  if [[ "$device_id" != emulator-* ]]; then
    echo "Refusing to run on a non-emulator Android serial: $device_id" >&2
    exit 3
  fi
  if command -v adb >/dev/null 2>&1; then
    adb_bin="$(command -v adb)"
  elif [[ -x "${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb" ]]; then
    adb_bin="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb"
  else
    echo "adb is not installed or discoverable." >&2
    exit 4
  fi
  if [[ "$("$adb_bin" -s "$device_id" get-state 2>/dev/null)" != "device" ]]; then
    echo "Android emulator $device_id is not ready." >&2
    exit 3
  fi
fi

if command -v maestro >/dev/null 2>&1; then
  maestro_bin="$(command -v maestro)"
elif [[ -x "${HOME:?}/.maestro/bin/maestro" ]]; then
  maestro_bin="$HOME/.maestro/bin/maestro"
else
  echo "Maestro is not installed or discoverable." >&2
  exit 4
fi

"$maestro_bin" test \
  --udid "$device_id" \
  --format JUNIT \
  --output "$artifact_dir/results.xml" \
  --test-output-dir "$artifact_dir" \
  --debug-output "$artifact_dir/debug" \
  "$flow"
