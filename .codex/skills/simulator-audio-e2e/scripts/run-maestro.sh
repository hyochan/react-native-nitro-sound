#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
device_id="${2:-}"
app_id="sound.example"

if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
  echo "Usage: $0 <ios|android> <simulator-udid|emulator-serial>" >&2
  exit 2
fi

if [[ -z "$device_id" ]]; then
  echo "An explicit virtual-device identifier is required." >&2
  exit 2
fi

script_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd -P)"
flow="$repo_root/e2e/maestro/audio-$platform.yaml"
artifact_dir="$repo_root/e2e/artifacts/$platform"
mkdir -p "$artifact_dir"

android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$android_sdk" ]]; then
  case "$(uname -s)" in
    Darwin) android_sdk="${HOME:?}/Library/Android/sdk" ;;
    Linux) android_sdk="${HOME:?}/Android/Sdk" ;;
  esac
fi

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
  elif [[ -n "$android_sdk" && -x "$android_sdk/platform-tools/adb" ]]; then
    adb_bin="$android_sdk/platform-tools/adb"
  else
    echo "adb is not installed or discoverable." >&2
    exit 4
  fi
  if [[ "$("$adb_bin" -s "$device_id" get-state 2>/dev/null)" != "device" ]]; then
    echo "Android emulator $device_id is not ready." >&2
    exit 3
  fi
fi

cleanup_done=0
cleanup_recordings() {
  cleanup_done=1
  local cleanup_failed=0

  if [[ "$platform" == "ios" ]]; then
    local app_container
    app_container="$(xcrun simctl get_app_container "$device_id" "$app_id" data 2>/dev/null || true)"
    if [[ -n "$app_container" && -d "$app_container" ]]; then
      find "$app_container" -type f \
        \( -name '*.m4a' -o -name '*.mp4' -o -name '*.wav' -o -name '*.aac' -o -name '*.caf' \) \
        -delete
      if find "$app_container" -type f \
        \( -name '*.m4a' -o -name '*.mp4' -o -name '*.wav' -o -name '*.aac' -o -name '*.caf' \) \
        -print -quit | grep -q .; then
        echo "Recording cleanup failed in the iOS app container." >&2
        cleanup_failed=1
      fi
    else
      echo "Could not locate the iOS app container to verify recording cleanup." >&2
      cleanup_failed=1
    fi
  elif "$adb_bin" -s "$device_id" shell pm path "$app_id" >/dev/null 2>&1; then
    if ! "$adb_bin" -s "$device_id" shell pm clear "$app_id" >/dev/null; then
      echo "Recording cleanup failed for the Android app data." >&2
      cleanup_failed=1
    fi
  else
    echo "Could not locate the Android app data to verify recording cleanup." >&2
    cleanup_failed=1
  fi

  find "$artifact_dir" -type f \
    \( -name '*.m4a' -o -name '*.mp4' -o -name '*.wav' -o -name '*.aac' -o -name '*.caf' -o -name '*.webm' \) \
    -delete
  if find "$artifact_dir" -type f \
    \( -name '*.m4a' -o -name '*.mp4' -o -name '*.wav' -o -name '*.aac' -o -name '*.caf' -o -name '*.webm' \) \
    -print -quit | grep -q .; then
    echo "Recording cleanup failed in $artifact_dir." >&2
    cleanup_failed=1
  fi

  return "$cleanup_failed"
}

trap 'if [[ "$cleanup_done" -eq 0 ]]; then cleanup_recordings || true; fi' EXIT
trap 'exit 130' INT TERM

if command -v maestro >/dev/null 2>&1; then
  maestro_bin="$(command -v maestro)"
elif [[ -x "${HOME:?}/.maestro/bin/maestro" ]]; then
  maestro_bin="$HOME/.maestro/bin/maestro"
else
  echo "Maestro is not installed or discoverable." >&2
  exit 4
fi

maestro_status=0
"$maestro_bin" test \
  --udid "$device_id" \
  --format JUNIT \
  --output "$artifact_dir/results.xml" \
  --test-output-dir "$artifact_dir" \
  --debug-output "$artifact_dir/debug" \
  "$flow" || maestro_status=$?

if ! cleanup_recordings; then
  echo "Runtime result is BLOCKED because recording cleanup was not verified." >&2
  exit 5
fi

exit "$maestro_status"
