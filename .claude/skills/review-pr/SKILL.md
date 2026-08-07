---
name: review-pr
description: Inspect and finish react-native-nitro-sound pull requests by fixing valid review or CI findings, using review-self as needed, and polling every five minutes until the exact head is clean.
---

# Review Pull Request (Claude Code)

Read `.codex/skills/review-pr/SKILL.md` and follow it as the canonical shared
workflow. Use Claude's real wake-up mechanism for its five-minute polling loop,
and use `.claude/skills/review-self/SKILL.md` only for the canonical single-round
fallback.
