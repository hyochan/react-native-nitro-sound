#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd -P)"
cd "$repo_root"

echo "Repository: $repo_root"
node --version
yarn --version
node -e "const p=require('./package.json'); console.log('React Native:', p.devDependencies['react-native']); console.log('Nitro Modules:', p.devDependencies['react-native-nitro-modules']); console.log('Nitrogen:', p.devDependencies.nitrogen)"

if command -v xcrun >/dev/null 2>&1; then
  echo "Available iOS Simulators:"
  xcrun simctl list devices available
fi

android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$android_sdk" ]]; then
  case "$(uname -s)" in
    Darwin) android_sdk="${HOME:?}/Library/Android/sdk" ;;
    Linux) android_sdk="${HOME:?}/Android/Sdk" ;;
  esac
fi

if command -v adb >/dev/null 2>&1; then
  adb_bin="$(command -v adb)"
elif [[ -n "$android_sdk" && -x "$android_sdk/platform-tools/adb" ]]; then
  adb_bin="$android_sdk/platform-tools/adb"
fi

if [[ -n "${adb_bin:-}" ]]; then
  echo "Android targets (select only an emulator-* serial):"
  "$adb_bin" devices -l
fi

if command -v emulator >/dev/null 2>&1; then
  emulator_bin="$(command -v emulator)"
elif [[ -n "$android_sdk" && -x "$android_sdk/emulator/emulator" ]]; then
  emulator_bin="$android_sdk/emulator/emulator"
fi

if [[ -n "${emulator_bin:-}" ]]; then
  echo "Android virtual devices:"
  "$emulator_bin" -list-avds
fi

if command -v maestro >/dev/null 2>&1; then
  maestro --version
elif [[ -x "${HOME:?}/.maestro/bin/maestro" ]]; then
  "$HOME/.maestro/bin/maestro" --version
else
  echo "Maestro is not installed or discoverable." >&2
  exit 1
fi
