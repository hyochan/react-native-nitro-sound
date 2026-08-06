#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
codex_home="${CODEX_HOME:-${HOME:?}/.codex}"
skills_dir="$codex_home/skills"

mkdir -p "$skills_dir"

for skill in \
  nitro-sound-workflows \
  generate-doc \
  ios-audio-e2e \
  android-audio-e2e \
  simulator-audio-e2e \
  funding-steward \
  rebase-main \
  review-self; do
  ln -sfn "$repo_root/.codex/skills/$skill" "$skills_dir/$skill"
  echo "Installed Codex skill: $skill"
done

echo "Target directory: $skills_dir"
