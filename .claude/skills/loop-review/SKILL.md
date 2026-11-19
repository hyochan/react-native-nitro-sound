---
name: loop-review
description: 'Run the react-native-nitro-sound latest-main-to-merge loop: review-self, PR review until the exact head is clean, the audio regression gate, merge, and exact clean main. Releases only when also requested.'
---

# Loop Review (Claude Code)

Read `.codex/skills/loop-review/SKILL.md` and follow it fully.

Use Claude Code's matching skills or commands for each delegated phase:

- `/review-self` for pre-PR stabilization and for the exact-head fallback when
  CodeRabbit is unavailable.
- `/commit --all --pr` for commit, push, PR, and labels.
- `/review-pr <PR>` for review threads, CI, and polling.
- `/simulator-audio-e2e` for the simulator rows of the regression gate, and
  `/ios-audio-e2e` or `/android-audio-e2e` for physical-device rows; hand those
  back to the user rather than merging.
- `/generate-doc` for the docs the PR carries.
- `/release` only when the user also asked for a release.
- `ScheduleWakeup` for every five-minute re-entry; never use a shell sleep loop.

Do not merge until the canonical exact-head clean gate is satisfied, and stop
without merging when a regression row has neither run nor been waived. After
merge, switch to `main`, fast-forward with no tag fetch, and verify exact clean
`main`.
