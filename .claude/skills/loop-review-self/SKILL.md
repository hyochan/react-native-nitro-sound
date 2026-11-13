---
name: loop-review-self
description: 'Land a minor docs, release-note, or repository-housekeeping change on main with no pull request: run review-self until two consecutive clean snapshots, run the checks the touched paths require, then commit and push straight to main and verify it.'
---

# Loop Review Self (Claude Code)

Read `.codex/skills/loop-review-self/SKILL.md` and follow its qualifying scope,
authority, review-until-clean phase, verification, direct push, confirmation,
and stop conditions as written.

- `/review-self` runs the review phase and owns the interval loop; do not start
  a second one. Use a real Claude wake-up mechanism for each recheck, never a
  sleeping shell or background loop.
- `/commit` covers staging and the commit message, but this skill pushes to
  `main` with no branch and no PR. Skip its branch step and do not pass `--pr`.
- An explicit `$loop-review-self` invocation is the commit and push request
  that the internal-workflow guard in `.claude/commands/commit.md` requires.
  Nothing else in that guard is relaxed.
